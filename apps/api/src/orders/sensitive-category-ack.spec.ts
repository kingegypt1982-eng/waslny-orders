import { ValidationPipe } from '@nestjs/common';
import { PolicyAcknowledgementType, ShipmentCategory } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { OrderEventsService } from '../order-events/order-events.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrdersService } from './orders.service';

// Reproduction: the exact payload the mobile order-review screen sends.
const mobileElectronicsPayload = {
  pickupLabel: 'Cairo, Egypt',
  pickupLatitude: 30,
  pickupLongitude: 31,
  deliveryLabel: 'Airport',
  deliveryLatitude: 30.1,
  deliveryLongitude: 31.1,
  category: 'ELECTRONICS',
  description: null,
  recipientName: 'Client',
  recipientPhone: '01000000000',
};

const mobilePapersPayload = { ...mobileElectronicsPayload, category: 'PAPERS' };

describe('sensitive category acknowledgement on POST /orders', () => {
  const tx = {
    order: { create: jest.fn() },
    orderEvent: { create: jest.fn().mockResolvedValue({ id: 'e1' }) },
  };
  const prisma = {
    $transaction: jest.fn(async (callback: any) => callback(tx)),
    pricingSettings: { upsert: jest.fn() },
    user: { findUnique: jest.fn() },
  };
  const redis = { nearbyCaptains: jest.fn() };
  const notifications = { create: jest.fn() };
  const policies = { hasAcknowledgement: jest.fn() };
  const orderEvents = new OrderEventsService(prisma as unknown as PrismaService);
  const service = new OrdersService(
    prisma as unknown as PrismaService,
    redis as unknown as RedisService,
    notifications as unknown as NotificationsService,
    orderEvents,
    policies as any,
  );

  const pipe = new ValidationPipe({
    whitelist: true,
    transform: true,
    forbidNonWhitelisted: true,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.pricingSettings.upsert.mockResolvedValue({
      basePrice: 30,
      pricePerKm: 8,
      commissionPercent: 10,
      minimumWalletBalance: 0,
      disabledCategories: [],
    });
    prisma.user.findUnique.mockResolvedValue({ phone: '+201000000000' });
    tx.order.create.mockImplementation(async ({ data }: any) => ({
      id: 'o9',
      ...data,
    }));
  });

  it('ELECTRONICS passes DTO validation (validation is not the cause)', async () => {
    await expect(
      pipe.transform(mobileElectronicsPayload, {
        type: 'body',
        metatype: CreateOrderDto,
      }),
    ).resolves.toMatchObject({ category: 'ELECTRONICS' });
  });

  it('ELECTRONICS without acknowledgement fails with 403 ACK_REQUIRED', async () => {
    policies.hasAcknowledgement.mockResolvedValue(null);

    const error = await service
      .create('client1', { ...mobileElectronicsPayload } as any)
      .catch((e) => e);
    // Show the exact API error text for the report.
    // eslint-disable-next-line no-console
    console.log(`REPRO_ERROR status=${error?.status} body=${JSON.stringify(error?.response)}`);

    expect(error?.status).toBe(403);
    expect(error?.response).toMatchObject({
      code: 'ACK_REQUIRED',
      type: PolicyAcknowledgementType.SENSITIVE_CATEGORY,
    });
    expect(tx.order.create).not.toHaveBeenCalled();
  });

  it('PAPERS (non-sensitive DOCUMENTS-like) creates without acknowledgement', async () => {
    const order = await service.create(
      'client1',
      { ...mobilePapersPayload } as any,
    );
    expect(order).toMatchObject({ id: 'o9' });
    expect(tx.order.create).toHaveBeenCalledTimes(1);
  });

  it('ELECTRONICS with acknowledgement proceeds to create', async () => {
    policies.hasAcknowledgement.mockResolvedValue({ id: 'ack9' });
    const order = await service.create(
      'client1',
      { ...mobileElectronicsPayload } as any,
    );
    expect(order).toMatchObject({ id: 'o9' });
    expect(policies.hasAcknowledgement).toHaveBeenCalledWith(
      'client1',
      PolicyAcknowledgementType.SENSITIVE_CATEGORY,
      { orderId: null, category: ShipmentCategory.ELECTRONICS },
    );
  });
});
