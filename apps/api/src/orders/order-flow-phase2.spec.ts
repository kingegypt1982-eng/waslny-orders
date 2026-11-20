import { ConflictException, ForbiddenException, UnprocessableEntityException } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { OrderEventsService } from '../order-events/order-events.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';
import { OrdersService } from './orders.service';

describe('Order flow phase 2 guards, location and rating', () => {
  const tx: any = {
    order: { findUnique: jest.fn(), updateMany: jest.fn(), update: jest.fn(), create: jest.fn() },
    orderEvent: { create: jest.fn().mockResolvedValue({ id: 'e1' }) },
    orderSkip: { deleteMany: jest.fn(), upsert: jest.fn() },
    captainProfile: { findUnique: jest.fn(), update: jest.fn() },
    pricingSettings: { upsert: jest.fn() },
    wallet: { updateMany: jest.fn(), update: jest.fn() },
    walletTransaction: { create: jest.fn() },
    user: { findUnique: jest.fn() },
  };
  const prisma: any = {
    $transaction: jest.fn(async (cb: any) => cb(tx)),
    $queryRaw: jest.fn().mockResolvedValue([]),
    $executeRaw: jest.fn().mockResolvedValue(1),
    order: { findUnique: jest.fn(), findMany: jest.fn(), updateMany: jest.fn(), create: jest.fn() },
    orderEvent: { findMany: jest.fn() },
    captainProfile: { findUnique: jest.fn(), update: jest.fn() },
    pricingSettings: { upsert: jest.fn() },
    user: { findUnique: jest.fn() },
    wallet: { findUnique: jest.fn() },
  };
  const redis: any = { updateCaptainLocation: jest.fn().mockResolvedValue(true), nearbyCaptains: jest.fn() };
  const notifications: any = { create: jest.fn().mockResolvedValue({ id: 'n1' }) };
  const orderEvents = new OrderEventsService(prisma as PrismaService);
  const policies: any = { hasAcknowledgement: jest.fn().mockResolvedValue({ id: 'ack1' }) };
  const service = new OrdersService(
    prisma as PrismaService,
    redis as RedisService,
    notifications as NotificationsService,
    orderEvents,
    policies,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.$transaction.mockImplementation(async (cb: any) => cb(tx));
    prisma.$queryRaw.mockResolvedValue([]);
    prisma.$executeRaw.mockResolvedValue(1);
    prisma.pricingSettings.upsert.mockResolvedValue({ basePrice: 30, pricePerKm: 8, commissionPercent: 10, minimumWalletBalance: 0, disabledCategories: [] });
    tx.pricingSettings.upsert.mockResolvedValue({ minimumWalletBalance: 0 });
    prisma.user.findUnique.mockResolvedValue({ phone: '+201000000000' });
    tx.user.findUnique.mockResolvedValue({ phone: '+201000000000' });
    notifications.create.mockResolvedValue({ id: 'n1' });
    redis.updateCaptainLocation.mockResolvedValue(true);
  });

  it('returns 409 on a second accept instead of debiting the wallet twice', async () => {
    tx.order.findUnique.mockResolvedValue({ id: 'o1', status: 'ACCEPTED', captainId: 'cap1', commission: 15 });
    tx.captainProfile.findUnique.mockResolvedValue({ userId: 'cap1', status: 'ACTIVE' });
    tx.wallet.updateMany.mockResolvedValue({ count: 1 });

    await expect(service.accept('o1', 'cap1')).rejects.toBeInstanceOf(ConflictException);
    expect(tx.wallet.updateMany).not.toHaveBeenCalled();
    expect(tx.walletTransaction.create).not.toHaveBeenCalled();
  });

  it('keeps the server state machine strict for direct status patches', async () => {
    tx.order.findUnique.mockResolvedValue({ id: 'o1', status: 'ACCEPTED', captainId: 'cap1' });
    await expect(service.transition('o1', 'cap1', 'DELIVERED' as any)).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(tx.order.updateMany).not.toHaveBeenCalled();
  });

  it('stores an active-trip heartbeat and mirrors it to Redis', async () => {
    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'ON_THE_WAY', captainId: 'cap1', clientId: 'cl1' });
    prisma.captainProfile.update.mockResolvedValue({});

    await expect(service.updateTripLocation('o1', 'cap1', 30.1, 31.2)).resolves.toEqual({ updated: true });
    expect(prisma.captainProfile.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: 'cap1' }, data: expect.objectContaining({ lastLat: 30.1, lastLng: 31.2 }) }),
    );
    expect(redis.updateCaptainLocation).toHaveBeenCalledWith('cap1', 30.1, 31.2);
  });

  it('rejects heartbeats from another captain or outside an active trip', async () => {
    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'ON_THE_WAY', captainId: 'cap1', clientId: 'cl1' });
    await expect(service.updateTripLocation('o1', 'intruder', 30, 31)).rejects.toBeInstanceOf(ForbiddenException);
    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'COMPLETED', captainId: 'cap1', clientId: 'cl1' });
    await expect(service.updateTripLocation('o1', 'cap1', 30, 31)).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(prisma.captainProfile.update).not.toHaveBeenCalled();
  });

  it('exposes the live captain position only to order participants', async () => {
    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'ON_THE_WAY', captainId: 'cap1', clientId: 'cl1' });
    prisma.captainProfile.findUnique.mockResolvedValue({ lastLat: 30.1, lastLng: 31.2, lastSeenAt: new Date('2026-01-01T00:00:00.000Z') });

    await expect(service.tripLocationForUser('o1', { id: 'cl1', role: 'CLIENT' } as any)).resolves.toEqual(
      expect.objectContaining({ latitude: 30.1, longitude: 31.2 }),
    );
    await expect(service.tripLocationForUser('o1', { id: 'other', role: 'CLIENT' } as any)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rates only a completed order and only once', async () => {
    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'DELIVERED', captainId: 'cap1', clientId: 'cl1' });
    await expect(service.rateOrder('o1', 'cl1', { score: 5 })).rejects.toBeInstanceOf(UnprocessableEntityException);

    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'COMPLETED', captainId: 'cap1', clientId: 'cl1' });
    await expect(service.rateOrder('o1', 'cl1', { score: 4, comment: ' great ' })).resolves.toEqual(
      expect.objectContaining({ orderId: 'o1', captainId: 'cap1', score: 4, comment: 'great' }),
    );
    expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);

    prisma.$queryRaw.mockResolvedValueOnce([{ id: 'r1' }]);
    await expect(service.rateOrder('o1', 'cl1', { score: 3 })).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
  });

  it('returns null when a completed order has no rating yet', async () => {
    prisma.order.findUnique.mockResolvedValue({ id: 'o1', status: 'COMPLETED', captainId: 'cap1', clientId: 'cl1' });
    await expect(service.ratingForUser('o1', { id: 'cl1', role: 'CLIENT' } as any)).resolves.toBeNull();
  });

  it('refunds the reserved commission when the client cancels before pickup', async () => {
    tx.order.findUnique.mockResolvedValue({ id: 'o1', status: 'ACCEPTED', captainId: 'cap1', clientId: 'cl1', commission: 15, reference: 'WS-1' });
    tx.order.updateMany.mockResolvedValue({ count: 1 });
    tx.wallet.update.mockResolvedValue({});
    tx.walletTransaction.create.mockResolvedValue({});

    await service.cancel('o1', 'cl1');
    expect(tx.wallet.update).toHaveBeenCalledWith({ where: { userId: 'cap1' }, data: { balance: { increment: expect.anything() } } });
    expect(tx.walletTransaction.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ type: 'COMMISSION_REFUND', userId: 'cap1' }) }),
    );
  });

  it('increments totalTrips only on client completion, with no wallet movement', async () => {
    tx.order.findUnique.mockResolvedValue({ id: 'o1', status: 'DELIVERED', captainId: 'cap1', clientId: 'cl1', reference: 'WS-1' });
    tx.order.updateMany.mockResolvedValue({ count: 1 });
    await service.complete('o1', 'cl1');

    expect(tx.captainProfile.update).toHaveBeenCalledWith({
      where: { userId: 'cap1' },
      data: { totalTrips: { increment: 1 } },
    });
    expect(tx.wallet.update).not.toHaveBeenCalled();
    expect(tx.walletTransaction.create).not.toHaveBeenCalled();
  });

  it('notifies the client on creation and the captain on acceptance', async () => {
    tx.order.create.mockImplementation(async ({ data }: any) => ({ id: 'o2', reference: 'WS-2', ...data }));
    await service.create('cl1', {
      pickupLabel: 'A', pickupLatitude: 30, pickupLongitude: 31,
      deliveryLabel: 'B', deliveryLatitude: 30.1, deliveryLongitude: 31.1,
      category: 'PACKAGE' as any, description: '', recipientName: 'R', recipientPhone: '+201000000000',
    });
    expect(notifications.create).toHaveBeenCalledWith(
      'cl1', expect.any(String), expect.any(String), 'ORDER',
      expect.objectContaining({ screen: 'ORDER_CREATED' }),
    );

    tx.order.findUnique.mockResolvedValue({ id: 'o2', status: 'SEARCHING_CAPTAIN', captainId: null, commission: 15, reference: 'WS-2' });
    tx.captainProfile.findUnique.mockResolvedValue({ userId: 'cap1', status: 'ACTIVE' });
    tx.wallet.updateMany.mockResolvedValue({ count: 1 });
    tx.order.updateMany.mockResolvedValue({ count: 1 });
    tx.order.findUnique.mockResolvedValueOnce({ id: 'o2', status: 'SEARCHING_CAPTAIN', captainId: null, commission: 15, reference: 'WS-2' });
    await service.accept('o2', 'cap1');
    expect(notifications.create).toHaveBeenCalledWith(
      'cap1', expect.any(String), expect.any(String), 'ORDER',
      expect.objectContaining({ screen: 'ORDER_ACCEPTED' }),
    );
  });
});
