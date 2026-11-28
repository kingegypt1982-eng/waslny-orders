import { INestApplication } from '@nestjs/common';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { JwtStrategy } from '../auth/jwt.strategy';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';

describe('Admin notification endpoints (guards)', () => {
  let app: INestApplication;
  let jwt: JwtService;
  const notifications = {
    list: jest.fn().mockResolvedValue({ items: [], unreadCount: 0, nextCursor: null }),
    markRead: jest.fn().mockResolvedValue({ marked: 1 }),
    markAllRead: jest.fn().mockResolvedValue({ marked: 2 }),
  };

  beforeAll(async () => {
    process.env.JWT_SECRET = 'unit-test-secret';
    const users: Record<string, any> = {
      admin: { id: 'admin', role: 'ADMIN', email: 'a@x.com', name: 'Admin', suspendedAt: null },
      client: { id: 'client', role: 'CLIENT', email: 'c@x.com', name: 'Client', suspendedAt: null },
    };
    const module = await Test.createTestingModule({
      imports: [PassportModule, JwtModule.register({ secret: 'unit-test-secret' })],
      controllers: [AdminController],
      providers: [
        JwtStrategy,
        RolesGuard,
        { provide: PrismaService, useValue: { user: { findUnique: jest.fn(async ({ where }: any) => users[where.id]) } } },
        { provide: AdminService, useValue: {} },
        { provide: AdminNotificationsService, useValue: notifications },
      ],
    }).compile();
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    await app.init();
    jwt = module.get(JwtService);
  });

  afterAll(async () => {
    await app?.close();
  });

  it('rejects anonymous callers with 401', async () => {
    await request(app.getHttpServer()).get('/api/v1/admin/notifications').expect(401);
  });

  it('rejects non-admin callers with 403', async () => {
    const token = await jwt.signAsync({ sub: 'client', role: 'CLIENT' });
    await request(app.getHttpServer())
      .get('/api/v1/admin/notifications')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  it('lets an admin list, mark one read and mark all read', async () => {
    const token = await jwt.signAsync({ sub: 'admin', role: 'ADMIN' });
    await request(app.getHttpServer())
      .get('/api/v1/admin/notifications?limit=20&unreadOnly=true')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect((res) => expect(res.body.unreadCount).toBe(0));
    await request(app.getHttpServer())
      .patch('/api/v1/admin/notifications/n1/read')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect((res) => expect(res.body).toEqual({ marked: 1 }));
    await request(app.getHttpServer())
      .post('/api/v1/admin/notifications/read-all')
      .set('Authorization', `Bearer ${token}`)
      .expect(201)
      .expect((res) => expect(res.body).toEqual({ marked: 2 }));
  });
});
