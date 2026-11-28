import { Injectable, Logger } from '@nestjs/common';
import { AdminNotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface AdminNotificationsQuery {
  limit?: number;
  cursor?: string;
  unreadOnly?: boolean;
}

const MAX_LIMIT = 100;

@Injectable()
export class AdminNotificationsService {
  private readonly logger = new Logger(AdminNotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Best-effort write: a broken notifications table must never break sign-up.
   * Callers intentionally do not await this method.
   */
  async create(
    type: AdminNotificationType,
    title: string,
    body: string,
    data?: Prisma.InputJsonValue,
  ): Promise<void> {
    try {
      await this.prisma.adminNotification.create({
        data: { type, title, body, data },
      });
    } catch (error) {
      this.logger.warn('Could not create admin notification', error);
    }
  }

  async list(query: AdminNotificationsQuery) {
    const limit = Math.min(Math.max(query.limit ?? 20, 1), MAX_LIMIT);
    const where: Prisma.AdminNotificationWhereInput = query.unreadOnly
      ? { readAt: null }
      : {};
    const items = await this.prisma.adminNotification.findMany({
      where,
      take: limit,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
    });
    const unreadCount = await this.prisma.adminNotification.count({
      where: { readAt: null },
    });
    return {
      items,
      unreadCount,
      nextCursor: items.length === limit ? items[items.length - 1].id : null,
    };
  }

  async markRead(id: string) {
    const result = await this.prisma.adminNotification.updateMany({
      where: { id, readAt: null },
      data: { readAt: new Date() },
    });
    return { marked: result.count };
  }

  async markAllRead() {
    const result = await this.prisma.adminNotification.updateMany({
      where: { readAt: null },
      data: { readAt: new Date() },
    });
    return { marked: result.count };
  }
}
