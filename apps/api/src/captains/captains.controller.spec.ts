import { BadRequestException, ConflictException } from '@nestjs/common';
import { CaptainsController } from './captains.controller';
import { NationalIdCryptoService } from './national-id-crypto.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';

describe('CaptainsController profile', () => {
  const prisma = {
    captainProfile: { findUnique: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  };
  const redis = { updateCaptainLocation: jest.fn() };
  const originalKey = process.env.NATIONAL_ID_ENCRYPTION_KEY;
  let crypto: NationalIdCryptoService;
  let controller: CaptainsController;

  beforeAll(() => {
    process.env.NATIONAL_ID_ENCRYPTION_KEY = Buffer.from('k'.repeat(32)).toString('base64');
    crypto = new NationalIdCryptoService();
    controller = new CaptainsController(
      prisma as unknown as PrismaService,
      redis as unknown as RedisService,
      crypto,
    );
  });

  afterAll(() => {
    if (originalKey === undefined) delete process.env.NATIONAL_ID_ENCRYPTION_KEY;
    else process.env.NATIONAL_ID_ENCRYPTION_KEY = originalKey;
  });

  beforeEach(() => jest.clearAllMocks());

  it('rejects an invalid national ID', async () => {
    await expect(
      controller.updateProfile({ id: 'u1' }, { nationalId: '123' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a duplicate national ID with 409 and does not reveal the other account', async () => {
    prisma.captainProfile.findFirst.mockResolvedValue({ userId: 'someone-else' });
    let caught: any;
    try {
      await controller.updateProfile({ id: 'u1' }, { nationalId: '30201011234567' });
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(ConflictException);
    expect(caught.getResponse()).toMatchObject({ code: 'NATIONAL_ID_DUPLICATE' });
    expect(JSON.stringify(caught.getResponse())).not.toContain('someone-else');
  });

  it('stores encrypted national ID and returns only the masked last4', async () => {
    prisma.captainProfile.findFirst.mockResolvedValue(null);
    prisma.captainProfile.update.mockImplementation(async ({ data }: any) => ({
      id: 'p1',
      userId: 'u1',
      status: 'PENDING',
      dateOfBirth: data.dateOfBirth,
      governorate: data.governorate,
      licenseNumber: data.licenseNumber,
      vehicleRegistrationNumber: data.vehicleRegistrationNumber,
      nationalIdLast4: data.nationalIdLast4,
    }));

    const result = (await controller.updateProfile(
      { id: 'u1' },
      { nationalId: '30201011234567', governorate: 'Cairo' },
    )) as any;

    expect(result.nationalIdLast4).toBe('4567');
    expect(result.nationalIdEncrypted).toBeUndefined();
    expect(JSON.stringify(result)).not.toContain('30201011234567');

    const stored = prisma.captainProfile.update.mock.calls[0][0].data;
    expect(stored.nationalIdEncrypted).toBeDefined();
    expect(crypto.decrypt(stored.nationalIdEncrypted)).toBe('30201011234567');
    expect(stored.nationalIdHash).toBe(crypto.hash('30201011234567'));
  });

  it('GET /me masks the encrypted national ID and lists missing fields', async () => {
    prisma.captainProfile.findUnique.mockResolvedValue({
      id: 'p1',
      userId: 'u1',
      status: 'PENDING',
      nationalIdEncrypted: crypto.encrypt('30201011234567'),
      nationalIdHash: crypto.hash('30201011234567'),
      nationalIdLast4: '4567',
      governorate: null,
      licenseNumber: null,
      vehicleRegistrationNumber: null,
      dateOfBirth: null,
      vehicleType: null,
      vehiclePlate: null,
      user: { id: 'u1', name: 'Cap', email: 'c@x.com', phone: null, wallet: null },
    });

    const result = (await controller.profile({ id: 'u1' })) as any;
    expect(result.nationalIdEncrypted).toBeUndefined();
    expect(result.nationalIdHash).toBeUndefined();
    expect(result.nationalIdLast4).toBe('4567');
    expect(result.missing).toEqual(
      expect.arrayContaining(['phone', 'governorate', 'licenseNumber', 'vehicleRegistrationNumber', 'dateOfBirth', 'vehicle']),
    );
    expect(result.missing).not.toContain('nationalId');
  });
});
