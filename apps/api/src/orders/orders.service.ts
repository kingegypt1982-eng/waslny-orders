import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { EventActor, NotificationType, OrderStatus, PolicyAcknowledgementType, Prisma, ProofType, PurchaseInvoiceStatus, ShipmentCategory, UserRole, WalletTransactionType } from '@prisma/client';
import { existsSync } from 'fs';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';
import { NotificationsService } from '../notifications/notifications.service';
import { OrderEventsService } from '../order-events/order-events.service';
import { PoliciesService } from '../policies/policies.service';
import { POLICY_VERSION } from '../policies/policy-content.v1';
import { CreateOrderDto } from './dto/create-order.dto';
import { SubmitInvoiceDto } from './dto/submit-invoice.dto';
import { RespondInvoiceDto } from './dto/respond-invoice.dto';
import { QuoteOrderDto } from './dto/quote-order.dto';
import { ProofPhotoInput, resolveUploadPath, saveProofPhoto } from './proof-upload';

const radians = (degrees: number) => degrees * Math.PI / 180;

export function distanceKm(fromLat: number, fromLon: number, toLat: number, toLon: number) {
  const deltaLat = radians(toLat - fromLat);
  const deltaLon = radians(toLon - fromLon);
  const arc = Math.sin(deltaLat / 2) ** 2 + Math.cos(radians(fromLat)) * Math.cos(radians(toLat)) * Math.sin(deltaLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(arc), Math.sqrt(1 - arc));
}

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly notifications: NotificationsService,
    private readonly orderEvents: OrderEventsService,
    private readonly policies: PoliciesService,
  ) {}

  /** Best-effort notification: never breaks the order flow. */
  private async notify(
    userId: string,
    title: string,
    body: string,
    type: NotificationType = NotificationType.ORDER,
    metadata?: Prisma.InputJsonValue,
  ) {
    try {
      await this.notifications.create(userId, title, body, type, metadata);
    } catch {
      // Notifications are non-critical; order state is authoritative in PostgreSQL.
    }
  }

  private notifyClient(order: { clientId: string; reference: string; id: string }, title: string, body: string) {
    return this.notify(order.clientId, title, body, NotificationType.ORDER, { orderId: order.id });
  }

  /**
   * Returns a previously reserved commission to the captain's wallet.
   * Must be called inside a transaction after the order row was updated.
   */
  private refundCommission(
    tx: Prisma.TransactionClient,
    captainId: string,
    order: { id: string; commission: unknown },
    note: string,
  ) {
    const amount = new Prisma.Decimal(order.commission as number);
    return (async () => {
      await tx.wallet.update({ where: { userId: captainId }, data: { balance: { increment: amount } } });
      await tx.walletTransaction.create({
        data: { userId: captainId, orderId: order.id, type: WalletTransactionType.COMMISSION_REFUND, amount, note },
      });
    })();
  }

  async quote(input: QuoteOrderDto) {
    const [pricing, distance] = await Promise.all([
      this.prisma.pricingSettings.upsert({ where: { id: 'default' }, update: {}, create: {} }),
      Promise.resolve(distanceKm(input.pickupLatitude, input.pickupLongitude, input.deliveryLatitude, input.deliveryLongitude)),
    ]);
    const distanceRounded = Math.round(distance * 100) / 100;
    const price = Number(pricing.basePrice) + distanceRounded * Number(pricing.pricePerKm);
    const commission = price * Number(pricing.commissionPercent) / 100;
    return { currency: 'EGP', distanceKm: distanceRounded, price: Number(price.toFixed(2)), commission: Number(commission.toFixed(2)) };
  }

  async create(clientId: string, input: CreateOrderDto) {
    const settings = await this.prisma.pricingSettings.upsert({ where: { id: 'default' }, update: {}, create: {} });
    if (settings.disabledCategories?.includes(input.category)) {
      throw new BadRequestException({ code: 'CATEGORY_DISABLED', message: 'هذه الفئة متوقفة مؤقتًا عن استقبال الطلبات' });
    }
    const budgetCategories: ShipmentCategory[] = [ShipmentCategory.PURCHASES, ShipmentCategory.FOOD];
    if (input.estimatedBudget !== undefined && !budgetCategories.includes(input.category)) {
      throw new BadRequestException('Estimated budget is only available for purchases and food');
    }
    if (isSensitiveCategory(input.category) && !(await this.policies.hasAcknowledgement(
      clientId,
      PolicyAcknowledgementType.SENSITIVE_CATEGORY,
      { orderId: null, category: input.category },
    ))) {
      throw ackRequired(PolicyAcknowledgementType.SENSITIVE_CATEGORY, { category: input.category });
    }
    const quote = await this.quote(input);
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
        data: {
          clientId, ...input, description: input.description?.trim() || '', status: OrderStatus.SEARCHING_CAPTAIN,
          distanceKm: quote.distanceKm, price: quote.price, commission: quote.commission,
        },
      });
      await this.orderEvents.record(tx, {
        orderId: order.id,
        fromStatus: null,
        toStatus: OrderStatus.SEARCHING_CAPTAIN,
        actorId: clientId,
        actorRole: EventActor.CLIENT,
        note: 'Order created',
      });
      return order;
    });
  }

  listForUser(user: { id: string; role: UserRole }) {
    return this.prisma.order.findMany({
      where: user.role === UserRole.CLIENT ? { clientId: user.id } : { captainId: user.id },
      include: { client: { select: { id: true, name: true, phone: true } }, captain: { select: { id: true, name: true, phone: true } } },
      orderBy: { createdAt: 'desc' }, take: 100,
    });
  }

  async getForUser(id: string, user: { id: string; role: UserRole }) {
    const order = await this.prisma.order.findUnique({ where: { id }, include: { client: true, captain: true } });
    if (!order) throw new NotFoundException('Order not found');
    if (user.role !== UserRole.ADMIN && order.clientId !== user.id && order.captainId !== user.id) {
      throw new ForbiddenException();
    }
    return order;
  }

  async available(latitude: number, longitude: number) {
    const nearby = await this.redis.nearbyCaptains(latitude, longitude);
    const ids = nearby.map((entry) => Array.isArray(entry) ? entry[0] : entry).filter((id): id is string => typeof id === 'string');
    const orders = await this.prisma.order.findMany({
      where: { status: { in: [OrderStatus.PENDING, OrderStatus.SEARCHING_CAPTAIN] }, captainId: null },
      orderBy: { createdAt: 'asc' }, take: 50,
    });
    if (!ids.length) return orders;
    return orders.filter((order) => ids.length > 0 && distanceKm(latitude, longitude, order.pickupLatitude, order.pickupLongitude) <= 10);
  }

  async accept(orderId: string, captainId: string) {
    const order = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      const captain = await tx.captainProfile.findUnique({ where: { userId: captainId } });
      const pricing = await tx.pricingSettings.upsert({ where: { id: 'default' }, update: {}, create: {} });
      if (!order || !captain) throw new NotFoundException('Order or captain not found');
      if (captain.status !== 'ACTIVE') throw new ForbiddenException('Captain account is not approved');
      if ((order.status !== OrderStatus.PENDING && order.status !== OrderStatus.SEARCHING_CAPTAIN) || order.captainId) {
        throw new UnprocessableEntityException('Order is no longer available');
      }
      if (!(await this.policies.hasAcknowledgement(captainId, PolicyAcknowledgementType.TERMS_CAPTAIN, { orderId: null, category: null }))) {
        throw ackRequired(PolicyAcknowledgementType.TERMS_CAPTAIN);
      }
      if (isSensitiveCategory(order.category) && !(await this.policies.hasAcknowledgement(
        captainId,
        PolicyAcknowledgementType.SENSITIVE_CATEGORY,
        { orderId, category: order.category },
      ))) {
        throw ackRequired(PolicyAcknowledgementType.SENSITIVE_CATEGORY, { orderId, category: order.category });
      }
      const required = Math.max(Number(order.commission), Number(pricing.minimumWalletBalance));
      const debit = await tx.wallet.updateMany({
        where: { userId: captainId, balance: { gte: new Prisma.Decimal(required) } },
        data: { balance: { decrement: new Prisma.Decimal(order.commission) } },
      });
      if (!debit.count) throw new UnprocessableEntityException('Insufficient wallet balance to accept this order');
      const assigned = await tx.order.updateMany({
        where: { id: orderId, captainId: null, status: { in: [OrderStatus.PENDING, OrderStatus.SEARCHING_CAPTAIN] } },
        data: { captainId, status: OrderStatus.ACCEPTED, acceptedAt: new Date() },
      });
      if (!assigned.count) throw new UnprocessableEntityException('Order was accepted by another captain');
      await tx.walletTransaction.create({
        data: { userId: captainId, orderId, type: WalletTransactionType.ORDER_COMMISSION, amount: new Prisma.Decimal(order.commission).negated(), note: 'Order commission reserved at acceptance' },
      });
      const updated = await tx.order.findUnique({ where: { id: orderId } });
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: order.status,
        toStatus: OrderStatus.ACCEPTED,
        actorId: captainId,
        actorRole: EventActor.CAPTAIN,
        note: 'Captain accepted the order',
      });
      return updated;
    });
    if (order) {
      await this.notifyClient(order, 'تم قبول طلبك', `قبل المندوب الطلب ${order.reference} وهو في الطريق إلى موقع الاستلام.`);
    }
    return order;
  }

  async transition(orderId: string, captainId: string, next: OrderStatus) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Order not found');
      if (order.captainId !== captainId) throw new ForbiddenException();
      this.assertAllowedTransition(order.status, next);
      // Pickup and delivery confirmations require photo proof: the direct
      // PATCH jumps below must go through POST /orders/:id/proof/pickup and
      // POST /orders/:id/proof/delivery instead. All other jumps stay allowed.
      if (
        (order.status === OrderStatus.ARRIVED_AT_PICKUP && next === OrderStatus.PICKED_UP) ||
        (order.status === OrderStatus.ON_THE_WAY && next === OrderStatus.DELIVERED)
      ) {
        throw new UnprocessableEntityException(
          'Pickup and delivery confirmations require photo proof. Use POST /orders/:id/proof/pickup or POST /orders/:id/proof/delivery.',
        );
      }
      const moved = await tx.order.update({
        where: { id: orderId },
        data: { status: next, ...(next === OrderStatus.DELIVERED ? { deliveredAt: new Date() } : {}) },
      });
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: order.status,
        toStatus: next,
        actorId: captainId,
        actorRole: EventActor.CAPTAIN,
        note: 'Captain updated the trip status',
      });
      return moved;
    });
    await this.notifyClient(updated, 'تحديث الطلب', `الطلب ${updated.reference}: ${arabicTripUpdate(next)}.`);
    return updated;
  }

  /** Single source of truth for the captain trip state machine, reused by proof submission. */
  private assertAllowedTransition(from: OrderStatus, next: OrderStatus) {
    const allowed: Partial<Record<OrderStatus, OrderStatus[]>> = {
      [OrderStatus.ACCEPTED]: [OrderStatus.ARRIVED_AT_PICKUP],
      [OrderStatus.ARRIVED_AT_PICKUP]: [OrderStatus.PICKED_UP],
      [OrderStatus.PICKED_UP]: [OrderStatus.ON_THE_WAY],
      [OrderStatus.ON_THE_WAY]: [OrderStatus.DELIVERED],
    };
    if (!allowed[from]?.includes(next)) {
      throw new UnprocessableEntityException(`Cannot move order from ${from} to ${next}`);
    }
  }

  /**
   * Proof submission shares the transition state machine: the proof row, the
   * status move, and the audit event are created in one transaction.
   * The photo file itself is written first and cannot roll back; a failed
   * transaction therefore leaves an orphan file but never inconsistent rows.
   */
  private submitProof(
    orderId: string,
    captainId: string,
    type: ProofType,
    next: OrderStatus,
    eventNote: string,
    photo?: ProofPhotoInput,
    note?: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Order not found');
      if (order.captainId !== captainId) throw new ForbiddenException();
      this.assertAllowedTransition(order.status, next);
      const existing = await tx.orderProof.findFirst({ where: { orderId, type } });
      if (existing) {
        throw new ConflictException(`${type === ProofType.PICKUP ? 'Pickup' : 'Delivery'} proof already submitted`);
      }
      let photoPath: string | null = null;
      if (photo) photoPath = (await saveProofPhoto(orderId, photo)).relativePath;
      await tx.orderProof.create({
        data: { orderId, type, photoPath, capturedById: captainId, note: note || undefined },
      });
      const updated = await tx.order.update({
        where: { id: orderId },
        data: { status: next, ...(next === OrderStatus.DELIVERED ? { deliveredAt: new Date() } : {}) },
      });
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: order.status,
        toStatus: next,
        actorId: captainId,
        actorRole: EventActor.CAPTAIN,
        note: eventNote,
      });
      return updated;
    });
  }

  async submitPickupProof(orderId: string, captainId: string, photo?: ProofPhotoInput, note?: string) {
    const updated = await this.submitProof(
      orderId, captainId, ProofType.PICKUP, OrderStatus.PICKED_UP, 'Pickup proof submitted', photo, note,
    );
    await this.notifyClient(updated, 'تم استلام الشحنة', `استلم المندوب شحنة الطلب ${updated.reference} وهي في الطريق إليك.`);
    return updated;
  }

  async submitDeliveryProof(orderId: string, captainId: string, photo?: ProofPhotoInput, note?: string) {
    // Commission settlement is intentionally untouched here: like a plain
    // transition to DELIVERED, no wallet movement happens; finalization still
    // occurs at client completion with the existing logic.
    const updated = await this.submitProof(
      orderId, captainId, ProofType.DELIVERY, OrderStatus.DELIVERED, 'Delivery proof submitted', photo, note,
    );
    await this.notifyClient(updated, 'تم تسليم الشحنة', `تم تسليم الطلب ${updated.reference}. يرجى تأكيد الاستلام.`);
    return updated;
  }

  async submitInvoice(orderId: string, captainId: string, input: SubmitInvoiceDto, photo?: ProofPhotoInput) {
    if (!photo) throw new BadRequestException('Invoice photo is required');
    if (!Number.isFinite(input.amount) || input.amount <= 0) throw new BadRequestException('Invoice amount must be greater than zero');
    const invoice = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Order not found');
      if (order.captainId !== captainId) throw new ForbiddenException();
      if (order.category !== ShipmentCategory.PURCHASES && order.category !== ShipmentCategory.FOOD) {
        throw new UnprocessableEntityException('Invoices are only available for purchases and food orders');
      }
      if (order.status !== OrderStatus.PICKED_UP && order.status !== OrderStatus.ON_THE_WAY) {
        throw new UnprocessableEntityException('Invoice can only be submitted after pickup and before delivery');
      }
      const existing = await tx.purchaseInvoice.findUnique({ where: { orderId } });
      if (existing) throw new ConflictException('Invoice already submitted');
      if (order.estimatedBudget && new Prisma.Decimal(input.amount).greaterThan(order.estimatedBudget)) {
        throw new BadRequestException({ code: 'BUDGET_EXCEEDED', message: 'Invoice amount exceeds the estimated budget' });
      }
      if (!(await this.policies.hasAcknowledgement(captainId, PolicyAcknowledgementType.PURCHASE_INVOICE, { orderId }))) {
        throw ackRequired(PolicyAcknowledgementType.PURCHASE_INVOICE, { orderId });
      }
      const photoPath = (await saveProofPhoto(orderId, photo)).relativePath;
      const created = await tx.purchaseInvoice.create({
        data: {
          orderId,
          capturedById: captainId,
          amount: new Prisma.Decimal(input.amount),
          photoPath,
          note: input.note,
        },
      });
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: order.status,
        toStatus: order.status,
        actorId: captainId,
        actorRole: EventActor.CAPTAIN,
        note: 'Purchase invoice submitted',
      });
      return created;
    });
    const order = await this.prisma.order.findUnique({ where: { id: orderId }, select: { clientId: true } });
    if (order) await this.notify(order.clientId, 'فاتورة مشتريات جديدة', 'أرسل المندوب فاتورة لمراجعتها.', NotificationType.ORDER, { orderId });
    return this.sanitizeInvoice(invoice);
  }

  async respondToInvoice(orderId: string, clientId: string, input: RespondInvoiceDto) {
    if (input.action === PurchaseInvoiceStatus.DISPUTED && !input.reason?.trim()) {
      throw new BadRequestException('A reason is required to dispute an invoice');
    }
    const invoice = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Order not found');
      if (order.clientId !== clientId) throw new ForbiddenException();
      const current = await tx.purchaseInvoice.findUnique({ where: { orderId } });
      if (!current) throw new NotFoundException('Invoice not found');
      if (current.status !== PurchaseInvoiceStatus.SUBMITTED || current.clientRespondedAt) {
        throw new ConflictException('Invoice has already received a client response');
      }
      const changed = await tx.purchaseInvoice.updateMany({
        where: { id: current.id, status: PurchaseInvoiceStatus.SUBMITTED, clientRespondedAt: null },
        data: {
          status: input.action,
          clientRespondedAt: new Date(),
          clientResponseReason: input.action === PurchaseInvoiceStatus.DISPUTED ? input.reason!.trim() : null,
        },
      });
      if (!changed.count) throw new ConflictException('Invoice has already received a client response');
      const updated = await tx.purchaseInvoice.findUnique({ where: { orderId } });
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: order.status,
        toStatus: order.status,
        actorId: clientId,
        actorRole: EventActor.CLIENT,
        note: input.action === PurchaseInvoiceStatus.CONFIRMED ? 'Client confirmed purchase invoice' : 'Client disputed purchase invoice',
      });
      return updated!;
    });
    const order = await this.prisma.order.findUnique({ where: { id: orderId }, select: { captainId: true } });
    if (order?.captainId) {
      await this.notify(order.captainId, 'رد العميل على الفاتورة', 'راجع رد العميل على فاتورة الطلب.', NotificationType.ORDER, { orderId });
    }
    return this.sanitizeInvoice(invoice);
  }

  async invoiceForUser(orderId: string, user: { id: string; role: UserRole }) {
    await this.getForUser(orderId, user);
    const invoice = await this.prisma.purchaseInvoice.findUnique({ where: { orderId } });
    if (!invoice) throw new NotFoundException('Invoice not found');
    return this.sanitizeInvoice(invoice);
  }

  async invoicePhotoForUser(orderId: string, user: { id: string; role: UserRole }) {
    await this.getForUser(orderId, user);
    const invoice = await this.prisma.purchaseInvoice.findUnique({ where: { orderId }, select: { photoPath: true } });
    if (!invoice?.photoPath || !invoice.photoPath.startsWith('proofs/')) throw new NotFoundException('Invoice photo not found');
    const resolved = resolveUploadPath(invoice.photoPath);
    if (!resolved || !existsSync(resolved.path)) throw new NotFoundException('Invoice photo is missing');
    const mimeType = invoice.photoPath.endsWith('.png') ? 'image/png' : invoice.photoPath.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
    return { path: resolved.path, mimeType };
  }

  private sanitizeInvoice<T extends { photoPath: string }>(invoice: T) {
    const { photoPath, ...visible } = invoice;
    return { ...visible, hasPhoto: !!photoPath };
  }

  async complete(orderId: string, clientId: string) {
    const order = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.order.updateMany({
        where: { id: orderId, clientId, status: OrderStatus.DELIVERED },
        data: { status: OrderStatus.COMPLETED, completedAt: new Date() },
      });
      if (!changed.count) throw new UnprocessableEntityException('Only the client can complete a delivered order');
      const completed = await tx.order.findUnique({ where: { id: orderId } });
      // The commission reserved at acceptance is now final: no wallet movement,
      // the held amount becomes company revenue. Count the trip for the captain.
      if (completed?.captainId) {
        await tx.captainProfile.update({
          where: { userId: completed.captainId },
          data: { totalTrips: { increment: 1 } },
        });
      }
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: OrderStatus.DELIVERED,
        toStatus: OrderStatus.COMPLETED,
        actorId: clientId,
        actorRole: EventActor.CLIENT,
        note: 'Client confirmed delivery',
      });
      return completed;
    });
    if (order?.captainId) {
      await this.notify(
        order.captainId,
        'Delivery completed',
        `Order ${order.reference} was completed. Thank you!`,
        NotificationType.ORDER,
        { orderId: order.id },
      );
    }
    return order;
  }

  /**
   * Client cancellation rules:
   * - Unassigned PENDING/SEARCHING_CAPTAIN -> CANCELLED, no money movement.
   * - Assigned but not yet picked up (ACCEPTED/ARRIVED_AT_PICKUP) -> CANCELLED
   *   + reserved commission refunded to the captain.
   * - PICKED_UP or later -> too late; only an admin can intervene.
   */
  async cancel(orderId: string, clientId: string) {
    const order = await this.prisma.$transaction(async (tx) => {
      const current = await tx.order.findUnique({ where: { id: orderId } });
      if (!current || current.clientId !== clientId) {
        throw new UnprocessableEntityException('This order can no longer be cancelled');
      }
      if (!current.captainId && (current.status === OrderStatus.PENDING || current.status === OrderStatus.SEARCHING_CAPTAIN)) {
        const cancelled = await tx.order.update({ where: { id: orderId }, data: { status: OrderStatus.CANCELLED } });
        await this.orderEvents.record(tx, {
          orderId,
          fromStatus: current.status,
          toStatus: OrderStatus.CANCELLED,
          actorId: clientId,
          actorRole: EventActor.CLIENT,
          note: 'Cancelled by client',
        });
        return cancelled;
      }
      if (current.captainId && (current.status === OrderStatus.ACCEPTED || current.status === OrderStatus.ARRIVED_AT_PICKUP)) {
        const cancelled = await tx.order.update({ where: { id: orderId }, data: { status: OrderStatus.CANCELLED } });
        await this.refundCommission(tx, current.captainId, current, 'Commission refunded on client cancellation');
        await this.orderEvents.record(tx, {
          orderId,
          fromStatus: current.status,
          toStatus: OrderStatus.CANCELLED,
          actorId: clientId,
          actorRole: EventActor.CLIENT,
          note: 'Cancelled by client',
        });
        return cancelled;
      }
      throw new UnprocessableEntityException('This order can no longer be cancelled');
    });
    if (order?.captainId) {
      await this.notify(
        order.captainId,
        'Order cancelled',
        `Order ${order.reference} was cancelled by the client. The reserved commission was refunded.`,
        NotificationType.ORDER,
        { orderId: order.id },
      );
    }
    return order;
  }

  /**
   * Captain release rules: the assigned captain may return an order to the
   * pool before pickup (ACCEPTED/ARRIVED_AT_PICKUP). The order goes back to
   * SEARCHING_CAPTAIN and the reserved commission is refunded.
   */
  async release(orderId: string, captainId: string) {
    const order = await this.prisma.$transaction(async (tx) => {
      const current = await tx.order.findUnique({ where: { id: orderId } });
      if (!current || current.captainId !== captainId) {
        throw new UnprocessableEntityException('This order cannot be released');
      }
      if (current.status !== OrderStatus.ACCEPTED && current.status !== OrderStatus.ARRIVED_AT_PICKUP) {
        throw new UnprocessableEntityException('This order cannot be released after pickup');
      }
      const released = await tx.order.update({
        where: { id: orderId },
        data: { captainId: null, status: OrderStatus.SEARCHING_CAPTAIN, acceptedAt: null },
      });
      await this.refundCommission(tx, captainId, current, 'Commission refunded on captain release');
      await this.orderEvents.record(tx, {
        orderId,
        fromStatus: current.status,
        toStatus: OrderStatus.SEARCHING_CAPTAIN,
        actorId: captainId,
        actorRole: EventActor.CAPTAIN,
        note: 'Released by captain',
      });
      return released;
    });
    if (order) {
      await this.notifyClient(order, 'جارٍ البحث عن مندوب جديد', `اعتذر المندوب عن الطلب ${order.reference}. نبحث لك عن مندوب آخر.`);
    }
    return order;
  }

  /**
   * Order timeline for the owning client or the assigned captain.
   * Ownership is enforced via getForUser; actor ids are stripped so neither
   * party sees the other side's internal identifiers.
   */
  async eventsForUser(id: string, user: { id: string; role: UserRole }) {
    await this.getForUser(id, user);
    const events = await this.orderEvents.list(id);
    return events.map(({ actorId: _actorId, ...event }) => event);
  }

  /**
   * Proofs visible to the owning client, the assigned captain, or an admin.
   * Internal file paths stay hidden; clients fetch photos via the dedicated
   * photo endpoint below.
   */
  async proofsForUser(id: string, user: { id: string; role: UserRole }) {
    await this.getForUser(id, user);
    const proofs = await this.prisma.orderProof.findMany({ where: { orderId: id }, orderBy: { createdAt: 'asc' } });
    return proofs.map((proof) => ({
      id: proof.id,
      type: proof.type,
      note: proof.note,
      capturedById: proof.capturedById,
      hasPhoto: !!proof.photoPath,
      createdAt: proof.createdAt,
    }));
  }

  /**
   * Resolves a proof photo for streaming. Ownership is enforced first, then
   * the stored path is confined to the proofs directory (traversal guard).
   */
  async proofPhotoForUser(orderId: string, proofId: string, user: { id: string; role: UserRole }) {
    await this.getForUser(orderId, user);
    const proof = await this.prisma.orderProof.findUnique({ where: { id: proofId } });
    if (!proof || proof.orderId !== orderId || !proof.photoPath || !proof.photoPath.startsWith('proofs/')) {
      throw new NotFoundException('Proof photo not found');
    }
    const resolved = resolveUploadPath(proof.photoPath);
    if (!resolved || !existsSync(resolved.path)) throw new NotFoundException('Proof photo is missing');
    const mimeType = proof.photoPath.endsWith('.png')
      ? 'image/png'
      : proof.photoPath.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    return { path: resolved.path, mimeType };
  }

  wallet(userId: string) {
    return this.prisma.wallet.findUnique({ where: { userId }, include: { user: { select: { id: true, name: true } } } });
  }

  transactions(userId: string) {
    return this.prisma.walletTransaction.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 100 });
  }
}

const sensitiveCategories: ShipmentCategory[] = [
  ShipmentCategory.MEDICINES,
  ShipmentCategory.PURCHASES,
  ShipmentCategory.FOOD,
  ShipmentCategory.ELECTRONICS,
];

function arabicTripUpdate(next: OrderStatus) {
  if (next === OrderStatus.ARRIVED_AT_PICKUP) return 'وصل المندوب إلى موقع الاستلام';
  if (next === OrderStatus.ON_THE_WAY) return 'الشحنة في الطريق إليك';
  return next;
}

function isSensitiveCategory(category: ShipmentCategory) {
  return sensitiveCategories.includes(category);
}

function ackRequired(type: PolicyAcknowledgementType, details: Record<string, string> = {}) {
  return new ForbiddenException({ code: 'ACK_REQUIRED', type, policyVersion: POLICY_VERSION, ...details });
}