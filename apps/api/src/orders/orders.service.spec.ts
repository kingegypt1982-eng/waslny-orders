import { ConflictException, ForbiddenException, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import * as fs from 'fs';
import { NotificationsService } from '../notifications/notifications.service';
import { OrderEventsService } from '../order-events/order-events.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';
import { OrdersService } from './orders.service';
import * as proofUpload from './proof-upload';

describe('OrdersService wallet rules', () => {
  const tx = {
    order: { findUnique: jest.fn(), updateMany: jest.fn(), update: jest.fn(), create: jest.fn() },
    orderEvent: { create: jest.fn().mockResolvedValue({ id: 'e1' }) },
    orderProof: { findFirst: jest.fn(), create: jest.fn() },
    captainProfile: { findUnique: jest.fn(), update: jest.fn() },
    pricingSettings: { upsert: jest.fn() },
    wallet: { updateMany: jest.fn(), update: jest.fn() },
    walletTransaction: { create: jest.fn() },
  };
  const prisma = {
    $transaction: jest.fn(async (callback: any) => callback(tx)),
    order: { findUnique: jest.fn(), updateMany: jest.fn(), update: jest.fn() },
    orderEvent: { findMany: jest.fn() },
    orderProof: { findFirst: jest.fn(), create: jest.fn(), findUnique: jest.fn(), findMany: jest.fn() },
    pricingSettings: { upsert: jest.fn() },
    captainProfile: { update: jest.fn() },
  };
  const redis = { nearbyCaptains: jest.fn(), updateCaptainLocation: jest.fn() };
  const notifications = { create: jest.fn().mockResolvedValue({ id: 'n1' }) };
  const orderEvents = new OrderEventsService(prisma as unknown as PrismaService);

  const service = new OrdersService(
    prisma as unknown as PrismaService,
    redis as unknown as RedisService,
    notifications as unknown as NotificationsService,
    orderEvents,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.$transaction.mockImplementation(async (callback: any) => callback(tx));
    tx.pricingSettings.upsert.mockResolvedValue({ minimumWalletBalance: 0 });
  });

  const acceptedOrder = {
    id: 'o1',
    reference: 'WS-1',
    clientId: 'client1',
    captainId: 'cap1',
    status: 'ACCEPTED',
    commission: 15,
  };

  it('reserves commission atomically when a captain accepts', async () => {
    tx.order.findUnique
      .mockResolvedValueOnce({ id: 'o1', status: 'SEARCHING_CAPTAIN', captainId: null, commission: 15 })
      .mockResolvedValueOnce({ ...acceptedOrder, status: 'ACCEPTED' });
    tx.captainProfile.findUnique.mockResolvedValue({ status: 'ACTIVE' });
    tx.wallet.updateMany.mockResolvedValue({ count: 1 });
    tx.order.updateMany.mockResolvedValue({ count: 1 });

    await service.accept('o1', 'cap1');

    expect(tx.wallet.updateMany).toHaveBeenCalled();
    expect(tx.walletTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ userId: 'cap1', type: 'ORDER_COMMISSION' }),
    });
    expect(notifications.create).toHaveBeenCalledWith(
      'client1',
      expect.any(String),
      expect.any(String),
      'ORDER',
      { orderId: 'o1' },
    );
  });

  it('rejects acceptance with insufficient wallet balance', async () => {
    tx.order.findUnique.mockResolvedValue({ id: 'o1', status: 'SEARCHING_CAPTAIN', captainId: null, commission: 50 });
    tx.captainProfile.findUnique.mockResolvedValue({ status: 'ACTIVE' });
    tx.wallet.updateMany.mockResolvedValue({ count: 0 });

    await expect(service.accept('o1', 'cap1')).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(tx.order.updateMany).not.toHaveBeenCalled();
  });

  it('lets a client cancel an unassigned order with no money movement', async () => {
    tx.order.findUnique.mockResolvedValue({ id: 'o1', clientId: 'client1', captainId: null, status: 'SEARCHING_CAPTAIN' });
    tx.order.update.mockResolvedValue({ id: 'o1', status: 'CANCELLED' });

    await service.cancel('o1', 'client1');

    expect(tx.order.update).toHaveBeenCalledWith({ where: { id: 'o1' }, data: { status: 'CANCELLED' } });
    expect(tx.wallet.update).not.toHaveBeenCalled();
    expect(tx.walletTransaction.create).not.toHaveBeenCalled();
  });

  it('refunds the reserved commission when a client cancels after accept', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder });
    tx.order.update.mockResolvedValue({ ...acceptedOrder, status: 'CANCELLED' });

    await service.cancel('o1', 'client1');

    expect(tx.wallet.update).toHaveBeenCalledWith({
      where: { userId: 'cap1' },
      data: { balance: { increment: expect.anything() } },
    });
    expect(tx.walletTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ userId: 'cap1', type: 'COMMISSION_REFUND' }),
    });
    expect(notifications.create).toHaveBeenCalledWith('cap1', expect.any(String), expect.any(String), 'ORDER', {
      orderId: 'o1',
    });
  });

  it('blocks client cancellation after pickup', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'PICKED_UP' });

    await expect(service.cancel('o1', 'client1')).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(tx.order.update).not.toHaveBeenCalled();
  });

  it('lets a captain release an order back to the pool with a refund', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder });
    tx.order.update.mockResolvedValue({ ...acceptedOrder, captainId: null, status: 'SEARCHING_CAPTAIN' });

    await service.release('o1', 'cap1');

    expect(tx.order.update).toHaveBeenCalledWith({
      where: { id: 'o1' },
      data: { captainId: null, status: 'SEARCHING_CAPTAIN', acceptedAt: null },
    });
    expect(tx.walletTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ userId: 'cap1', type: 'COMMISSION_REFUND' }),
    });
    expect(notifications.create).toHaveBeenCalledWith('client1', expect.any(String), expect.any(String), 'ORDER', {
      orderId: 'o1',
    });
  });

  it('blocks captain release after pickup', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'ON_THE_WAY' });

    await expect(service.release('o1', 'cap1')).rejects.toBeInstanceOf(UnprocessableEntityException);
  });

  it('finalizes commission on completion without further wallet movement', async () => {
    tx.order.updateMany.mockResolvedValue({ count: 1 });
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'COMPLETED' });

    await service.complete('o1', 'client1');

    expect(tx.captainProfile.update).toHaveBeenCalledWith({
      where: { userId: 'cap1' },
      data: { totalTrips: { increment: 1 } },
    });
    // Held commission becomes revenue: no credit back to the captain.
    expect(tx.wallet.update).not.toHaveBeenCalled();
    expect(notifications.create).toHaveBeenCalledWith('cap1', expect.any(String), expect.any(String), 'ORDER', {
      orderId: 'o1',
    });
  });

  it('only completes delivered orders', async () => {
    tx.order.updateMany.mockResolvedValue({ count: 0 });

    await expect(service.complete('o1', 'client1')).rejects.toBeInstanceOf(UnprocessableEntityException);
  });

  it('records an event when an order is created', async () => {
    prisma.pricingSettings.upsert.mockResolvedValue({ basePrice: 30, pricePerKm: 8, commissionPercent: 10, minimumWalletBalance: 0 });
    tx.order.create.mockImplementation(async ({ data }: any) => ({ id: 'o9', ...data }));
    await service.create('client1', {
      pickupLabel: 'A', pickupLatitude: 30, pickupLongitude: 31,
      deliveryLabel: 'B', deliveryLatitude: 30.1, deliveryLongitude: 31.1,
      category: 'PACKAGE' as any, description: 'Box', recipientName: 'R', recipientPhone: '+201000000000',
    });

    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'o9', fromStatus: null, toStatus: 'SEARCHING_CAPTAIN',
        actorId: 'client1', actorRole: 'CLIENT',
      }),
    });
  });

  it('records an event when a captain accepts', async () => {
    tx.order.findUnique
      .mockResolvedValueOnce({ id: 'o1', status: 'SEARCHING_CAPTAIN', captainId: null, commission: 15 })
      .mockResolvedValueOnce({ ...acceptedOrder, status: 'ACCEPTED' });
    tx.captainProfile.findUnique.mockResolvedValue({ status: 'ACTIVE' });
    tx.wallet.updateMany.mockResolvedValue({ count: 1 });
    tx.order.updateMany.mockResolvedValue({ count: 1 });

    await service.accept('o1', 'cap1');

    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'o1', fromStatus: 'SEARCHING_CAPTAIN', toStatus: 'ACCEPTED',
        actorId: 'cap1', actorRole: 'CAPTAIN',
      }),
    });
  });

  it('records an event on trip status transition', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder });
    tx.order.update.mockImplementation(async ({ data }: any) => ({ ...acceptedOrder, ...data }));

    await service.transition('o1', 'cap1', 'ARRIVED_AT_PICKUP' as any);

    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'o1', fromStatus: 'ACCEPTED', toStatus: 'ARRIVED_AT_PICKUP',
        actorId: 'cap1', actorRole: 'CAPTAIN',
      }),
    });
  });

  it('rejects direct PATCH jumps that require photo proof', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'ARRIVED_AT_PICKUP' });

    await expect(service.transition('o1', 'cap1', 'PICKED_UP' as any)).rejects.toBeInstanceOf(
      UnprocessableEntityException,
    );
    expect(tx.order.update).not.toHaveBeenCalled();

    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'ON_THE_WAY' });

    await expect(service.transition('o1', 'cap1', 'DELIVERED' as any)).rejects.toBeInstanceOf(
      UnprocessableEntityException,
    );
    expect(tx.order.update).not.toHaveBeenCalled();
  });

  it('records an event on client cancellation', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder });
    tx.order.update.mockResolvedValue({ ...acceptedOrder, status: 'CANCELLED' });

    await service.cancel('o1', 'client1');

    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'o1', fromStatus: 'ACCEPTED', toStatus: 'CANCELLED',
        actorId: 'client1', actorRole: 'CLIENT',
      }),
    });
  });

  it('records an event on completion and on captain release', async () => {
    tx.order.updateMany.mockResolvedValue({ count: 1 });
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'COMPLETED' });

    await service.complete('o1', 'client1');
    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'o1', fromStatus: 'DELIVERED', toStatus: 'COMPLETED',
        actorId: 'client1', actorRole: 'CLIENT',
      }),
    });

    jest.clearAllMocks();
    prisma.$transaction.mockImplementation(async (callback: any) => callback(tx));
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder });
    tx.order.update.mockResolvedValue({ ...acceptedOrder, captainId: null, status: 'SEARCHING_CAPTAIN' });

    await service.release('o1', 'cap1');
    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'o1', fromStatus: 'ACCEPTED', toStatus: 'SEARCHING_CAPTAIN',
        actorId: 'cap1', actorRole: 'CAPTAIN',
      }),
    });
  });

  it('leaves no event behind when the transaction fails', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder });
    tx.order.update.mockRejectedValue(new Error('db down'));

    await expect(service.transition('o1', 'cap1', 'ARRIVED_AT_PICKUP' as any)).rejects.toThrow('db down');
    expect(tx.orderEvent.create).not.toHaveBeenCalled();
  });

  it('shows the timeline to the owner without actor ids', async () => {
    prisma.order.findUnique.mockResolvedValue({ ...acceptedOrder, client: {}, captain: {} });
    prisma.orderEvent.findMany.mockResolvedValue([
      { id: 'e1', orderId: 'o1', fromStatus: null, toStatus: 'SEARCHING_CAPTAIN', actorId: 'client1', actorRole: 'CLIENT', note: 'Order created', createdAt: new Date() },
    ]);

    const events = await service.eventsForUser('o1', { id: 'client1', role: 'CLIENT' as any });

    expect(events).toHaveLength(1);
    expect(events[0]).not.toHaveProperty('actorId');
    expect(events[0]).toMatchObject({ toStatus: 'SEARCHING_CAPTAIN', actorRole: 'CLIENT' });
  });

  it('forbids strangers from reading the timeline', async () => {
    prisma.order.findUnique.mockResolvedValue({ ...acceptedOrder, client: {}, captain: {} });

    await expect(service.eventsForUser('o1', { id: 'stranger', role: 'CLIENT' as any })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma.orderEvent.findMany).not.toHaveBeenCalled();
  });

  const arrivedOrder = { ...acceptedOrder, status: 'ARRIVED_AT_PICKUP' };
  const onTheWayOrder = { ...acceptedOrder, status: 'ON_THE_WAY' };
  const pngPhoto = {
    buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]),
    size: 9,
  };

  it('submits pickup proof and moves to PICKED_UP', async () => {
    tx.order.findUnique.mockResolvedValue({ ...arrivedOrder });
    tx.orderProof.findFirst.mockResolvedValue(null);
    jest.spyOn(proofUpload, 'saveProofPhoto').mockResolvedValue({ relativePath: 'proofs/o1/x.jpg', mimeType: 'image/jpeg' });
    tx.orderProof.create.mockImplementation(async ({ data }: any) => ({ id: 'p1', ...data }));
    tx.order.update.mockImplementation(async ({ data }: any) => ({ ...arrivedOrder, ...data }));

    await service.submitPickupProof('o1', 'cap1', pngPhoto, 'Box handed over');

    expect(tx.orderProof.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ orderId: 'o1', type: 'PICKUP', photoPath: 'proofs/o1/x.jpg', capturedById: 'cap1' }),
    });
    expect(tx.order.update).toHaveBeenCalledWith({
      where: { id: 'o1' },
      data: expect.objectContaining({ status: 'PICKED_UP' }),
    });
    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ fromStatus: 'ARRIVED_AT_PICKUP', toStatus: 'PICKED_UP', actorRole: 'CAPTAIN' }),
    });
    expect(notifications.create).toHaveBeenCalledWith('client1', expect.any(String), expect.any(String), 'ORDER', {
      orderId: 'o1',
    });
  });

  it('rejects pickup proof in the wrong state, by a stranger captain, or twice', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'ACCEPTED' });
    tx.orderProof.findFirst.mockResolvedValue(null);

    await expect(service.submitPickupProof('o1', 'cap1')).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(tx.orderProof.create).not.toHaveBeenCalled();

    tx.order.findUnique.mockResolvedValue({ ...arrivedOrder, captainId: 'capX' });
    await expect(service.submitPickupProof('o1', 'cap1')).rejects.toBeInstanceOf(ForbiddenException);

    tx.order.findUnique.mockResolvedValue({ ...arrivedOrder });
    tx.orderProof.findFirst.mockResolvedValue({ id: 'p1' });
    await expect(service.submitPickupProof('o1', 'cap1')).rejects.toBeInstanceOf(ConflictException);
    expect(tx.order.update).not.toHaveBeenCalled();
  });

  it('submits delivery proof and moves to DELIVERED', async () => {
    tx.order.findUnique.mockResolvedValue({ ...onTheWayOrder });
    tx.orderProof.findFirst.mockResolvedValue(null);
    tx.orderProof.create.mockImplementation(async ({ data }: any) => ({ id: 'p2', ...data }));
    tx.order.update.mockImplementation(async ({ data }: any) => ({ ...onTheWayOrder, ...data }));

    await service.submitDeliveryProof('o1', 'cap1');

    expect(tx.orderProof.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ orderId: 'o1', type: 'DELIVERY', photoPath: null, capturedById: 'cap1' }),
    });
    expect(tx.order.update).toHaveBeenCalledWith({
      where: { id: 'o1' },
      data: expect.objectContaining({ status: 'DELIVERED' }),
    });
    expect(tx.orderEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ fromStatus: 'ON_THE_WAY', toStatus: 'DELIVERED', actorRole: 'CAPTAIN' }),
    });
  });

  it('rejects delivery proof in the wrong state or by a stranger captain', async () => {
    tx.order.findUnique.mockResolvedValue({ ...acceptedOrder, status: 'PICKED_UP' });
    tx.orderProof.findFirst.mockResolvedValue(null);

    await expect(service.submitDeliveryProof('o1', 'cap1')).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(tx.orderProof.create).not.toHaveBeenCalled();

    tx.order.findUnique.mockResolvedValue({ ...onTheWayOrder, captainId: 'capX' });
    await expect(service.submitDeliveryProof('o1', 'cap1')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('changes nothing when proof persistence fails', async () => {
    tx.order.findUnique.mockResolvedValue({ ...arrivedOrder });
    tx.orderProof.findFirst.mockResolvedValue(null);
    tx.orderProof.create.mockRejectedValue(new Error('db down'));

    await expect(service.submitPickupProof('o1', 'cap1')).rejects.toThrow('db down');
    expect(tx.order.update).not.toHaveBeenCalled();
    expect(tx.orderEvent.create).not.toHaveBeenCalled();
  });

  it('aborts the whole submission when the status move fails', async () => {
    tx.order.findUnique.mockResolvedValue({ ...arrivedOrder });
    tx.orderProof.findFirst.mockResolvedValue(null);
    tx.orderProof.create.mockImplementation(async ({ data }: any) => ({ id: 'p1', ...data }));
    tx.order.update.mockRejectedValue(new Error('db down'));

    await expect(service.submitPickupProof('o1', 'cap1')).rejects.toThrow('db down');
    // In production the surrounding transaction rolls the proof row back too.
    expect(tx.orderEvent.create).not.toHaveBeenCalled();
  });

  it('lists proofs to the owner without internal paths, and forbids strangers', async () => {
    prisma.order.findUnique.mockResolvedValue({ ...acceptedOrder, client: {}, captain: {} });
    prisma.orderProof.findMany.mockResolvedValue([
      { id: 'p1', orderId: 'o1', type: 'PICKUP', note: null, capturedById: 'cap1', photoPath: 'proofs/o1/x.jpg', createdAt: new Date() },
    ]);

    const proofs = await service.proofsForUser('o1', { id: 'client1', role: 'CLIENT' as any });
    expect(proofs).toHaveLength(1);
    expect(proofs[0]).not.toHaveProperty('photoPath');
    expect(proofs[0]).toMatchObject({ type: 'PICKUP', hasPhoto: true });

    await expect(service.proofsForUser('o1', { id: 'stranger', role: 'CLIENT' as any })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('streams proof photos to authorized parties only', async () => {
    prisma.order.findUnique.mockResolvedValue({ ...acceptedOrder, client: {}, captain: {} });
    prisma.orderProof.findUnique.mockResolvedValue({
      id: 'p1', orderId: 'o1', type: 'PICKUP', photoPath: 'proofs/o1/x.jpg',
    });
    jest.spyOn(fs, 'existsSync').mockReturnValue(true);

    const file = await service.proofPhotoForUser('o1', 'p1', { id: 'cap1', role: 'CAPTAIN' as any });
    expect(file.path.endsWith('x.jpg')).toBe(true);
    expect(file.mimeType).toBe('image/jpeg');

    await expect(
      service.proofPhotoForUser('o1', 'p1', { id: 'stranger', role: 'CLIENT' as any }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    prisma.orderProof.findUnique.mockResolvedValue({ id: 'p1', orderId: 'other', type: 'PICKUP', photoPath: 'proofs/other/x.jpg' });
    await expect(
      service.proofPhotoForUser('o1', 'p1', { id: 'client1', role: 'CLIENT' as any }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
