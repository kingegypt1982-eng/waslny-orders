import { AdminNotificationType } from '@prisma/client';
import { AdminNotificationsService } from './admin-notifications.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AdminNotificationsService', () => {
  const created: any[] = [];
  const prisma = {
    adminNotification: {
      create: jest.fn(async ({ data }: any) => {
        created.push({ ...data, id: `n${created.length + 1}`, createdAt: new Date() });
        return created[created.length - 1];
      }),
      findMany: jest.fn(async ({ take }: any) => created.slice(0, take)),
      count: jest.fn(async ({ where }: any) => created.filter((n) => where.readAt === null ? n.readAt == null : true).length),
      updateMany: jest.fn(async ({ where, data }: any) => {
        let count = 0;
        for (const n of created) {
          if (where.id && n.id !== where.id) continue;
          if (where.readAt === null && n.readAt != null) continue;
          n.readAt = data.readAt;
          count += 1;
        }
        return { count };
      }),
    },
  };
  const service = new AdminNotificationsService(prisma as unknown as PrismaService);

  beforeEach(() => {
    jest.clearAllMocks();
    created.length = 0;
  });

  it('stores a captain notification without sensitive fields', async () => {
    await service.create(
      AdminNotificationType.CAPTAIN_REGISTERED,
      'New captain awaiting review',
      'Captain One signed up as a captain.',
      { role: 'CAPTAIN', userId: 'u1' },
    );

    expect(created).toHaveLength(1);
    expect(created[0].data).toEqual({ role: 'CAPTAIN', userId: 'u1' });
  });

  it('never throws when persistence fails', async () => {
    (prisma.adminNotification.create as jest.Mock).mockRejectedValueOnce(new Error('db down'));

    await expect(
      service.create(AdminNotificationType.CLIENT_REGISTERED, 't', 'b'),
    ).resolves.toBeUndefined();
  });

  it('counts unread items and marks one or all as read', async () => {
    await service.create(AdminNotificationType.CLIENT_REGISTERED, 't1', 'b1');
    await service.create(AdminNotificationType.CAPTAIN_REGISTERED, 't2', 'b2');

    const before = await service.list({ limit: 20 });
    expect(before.unreadCount).toBe(2);
    expect(before.items).toHaveLength(2);

    expect(await service.markRead('n1')).toEqual({ marked: 1 });
    expect((await service.list({ unreadOnly: true })).unreadCount).toBe(1);

    expect(await service.markAllRead()).toEqual({ marked: 1 });
    expect((await service.list({ unreadOnly: true })).unreadCount).toBe(0);
  });

  it('caps the requested limit at 100', async () => {
    const result = await service.list({ limit: 500 });

    expect(prisma.adminNotification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ take: 100 }),
    );
    expect(result.nextCursor).toBeNull();
  });
});
