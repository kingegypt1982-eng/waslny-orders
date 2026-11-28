import { JwtService } from '@nestjs/jwt';
import { AdminNotificationType } from '@prisma/client';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';

describe('admin notifications on sign-up', () => {
  const prisma = {
    user: { findUnique: jest.fn(), create: jest.fn() },
  };
  const jwt = { signAsync: jest.fn().mockResolvedValue('token') };
  const notifications = { create: jest.fn().mockResolvedValue(undefined) };
  const service = new AuthService(
    prisma as unknown as PrismaService,
    jwt as unknown as JwtService,
    notifications as unknown as AdminNotificationsService,
  );

  const clientPayload = {
    email: 'client@example.com', password: 'Secret123', name: 'Client One',
    phone: '+201000000000', role: 'CLIENT' as const,
  };
  const captainPayload = {
    ...clientPayload, email: 'captain@example.com', name: 'Captain One',
    role: 'CAPTAIN' as const, vehicleType: 'Van', vehiclePlate: 'ABC123',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    jwt.signAsync.mockResolvedValue('token');
    notifications.create.mockResolvedValue(undefined);
    prisma.user.findUnique.mockResolvedValue(null);
    prisma.user.create.mockImplementation(async ({ data }: any) => ({
      id: 'u1', name: data.name, role: data.role, email: data.email,
    }));
  });

  it('creates a client notification on email registration', async () => {
    await service.register(clientPayload);

    expect(notifications.create).toHaveBeenCalledWith(
      AdminNotificationType.CLIENT_REGISTERED,
      expect.any(String),
      expect.stringContaining('Client One'),
      { role: 'CLIENT', userId: 'u1' },
    );
  });

  it('creates a captain notification on email registration', async () => {
    await service.register(captainPayload);

    expect(notifications.create).toHaveBeenCalledWith(
      AdminNotificationType.CAPTAIN_REGISTERED,
      expect.any(String),
      expect.stringContaining('Captain One'),
      { role: 'CAPTAIN', userId: 'u1' },
    );
  });

  it('creates notifications for new Google accounts only', async () => {
    jest.spyOn(service, 'verifyGoogleToken').mockResolvedValue({
      sub: 'g-1', email: 'google@example.com', name: 'Google Client',
    });
    prisma.user.findUnique
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ phone: null, captain: null });

    await service.googleLogin({ idToken: 'x', role: 'CLIENT', termsAccepted: true } as any);

    expect(notifications.create).toHaveBeenCalledTimes(1);
    expect(notifications.create).toHaveBeenCalledWith(
      AdminNotificationType.CLIENT_REGISTERED,
      expect.any(String),
      expect.stringContaining('Google Client'),
      expect.objectContaining({ role: 'CLIENT', userId: 'u1' }),
    );
  });

  it('does not break registration when notification creation fails', async () => {
    notifications.create.mockRejectedValueOnce(new Error('notification store down'));

    await expect(service.register(clientPayload)).resolves.toMatchObject({
      accessToken: 'token',
    });
  });
});
