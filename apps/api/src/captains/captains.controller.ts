import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { BadRequestException, ConflictException, Param, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { IsNumber, Max, Min } from 'class-validator';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { dirname, join } from 'path';
import { memoryStorage } from 'multer';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';
import { CurrentUser, Roles } from '../auth/auth.decorators';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';
import { NationalIdCryptoService } from './national-id-crypto.service';
import { validateEgyptianNationalId } from './national-id.util';
import { CaptainProfileUpdateDto } from './captain-profile.dto';

class LocationDto {
  @IsNumber() @Min(-90) @Max(90) latitude: number;
  @IsNumber() @Min(-180) @Max(180) longitude: number;
}

@ApiTags('Captains')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('CAPTAIN')
@Controller('captains')
export class CaptainsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly crypto: NationalIdCryptoService,
  ) {}

  @Get('me') async profile(@CurrentUser() user: { id: string }) {
    const profile = await this.prisma.captainProfile.findUnique({
      where: { userId: user.id },
      include: { user: { select: { id: true, name: true, email: true, phone: true, wallet: true } } },
    });
    if (!profile) return profile;
    const missing: string[] = [];
    if (!profile.user?.phone?.trim()) missing.push('phone');
    if (!profile.nationalIdHash || !profile.nationalIdLast4) missing.push('nationalId');
    if (!profile.governorate) missing.push('governorate');
    if (!profile.licenseNumber) missing.push('licenseNumber');
    if (!profile.vehicleRegistrationNumber) missing.push('vehicleRegistrationNumber');
    if (!profile.dateOfBirth) missing.push('dateOfBirth');
    if (!profile.vehicleType || !profile.vehiclePlate) missing.push('vehicle');
    const safe = { ...profile } as Record<string, unknown>;
    delete safe.nationalIdEncrypted;
    delete safe.nationalIdHash;
    return { ...safe, missing };
  }

  @Post('documents/:type')
  @UseInterceptors(FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: 8 * 1024 * 1024 },
    fileFilter: (_request, file, callback) => {
      if (!['application/pdf', 'image/jpeg', 'image/png'].includes(file.mimetype)) {
        callback(new BadRequestException('Upload a PDF, JPG, or PNG file'), false);
        return;
      }
      callback(null, true);
    },
  }))
  async uploadDocument(
    @CurrentUser() user: { id: string },
    @Param('type') type: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const field = documentFields[type as keyof typeof documentFields];
    if (!field || !file) throw new BadRequestException('Document type and file are required');
    const extension = file.mimetype === 'application/pdf' ? '.pdf' : file.mimetype === 'image/png' ? '.png' : '.jpg';
    const relativePath = join('captains', user.id, `${randomUUID()}${extension}`);
    const absolutePath = join(process.cwd(), 'uploads', relativePath);
    await mkdir(dirname(absolutePath), { recursive: true });
    await writeFile(absolutePath, file.buffer);
    await this.prisma.captainProfile.update({ where: { userId: user.id }, data: { [field]: relativePath } });
    return { type, uploaded: true };
  }

  @Patch('me/profile')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  async updateProfile(@CurrentUser() user: { id: string }, @Body() body: CaptainProfileUpdateDto) {
    const data: any = {};

    if (body.phone !== undefined) {
      data.user = { update: { phone: body.phone } };
    }

    if (body.governorate !== undefined) {
      data.governorate = body.governorate;
    }
    if (body.licenseNumber !== undefined) {
      data.licenseNumber = body.licenseNumber.trim() || null;
    }
    if (body.vehicleRegistrationNumber !== undefined) {
      data.vehicleRegistrationNumber = body.vehicleRegistrationNumber.trim() || null;
    }

    if (body.dateOfBirth !== undefined) {
      const parsed = new Date(body.dateOfBirth);
      if (Number.isNaN(parsed.getTime())) throw new BadRequestException('dateOfBirth must be a valid date');
      data.dateOfBirth = parsed;
    }

    if (body.nationalId !== undefined) {
      const nid = body.nationalId.trim();
      const validation = validateEgyptianNationalId(nid);
      if (!validation.valid) {
        throw new BadRequestException(validation.error || 'Invalid national ID');
      }
      const hash = this.crypto.hash(nid);
      const exists = await this.prisma.captainProfile.findFirst({
        where: {
          nationalIdHash: hash,
          userId: { not: user.id },
        },
        select: { userId: true },
      });
      if (exists) {
        throw new ConflictException({ code: 'NATIONAL_ID_DUPLICATE', message: 'National ID is already registered' });
      }
      data.nationalIdEncrypted = this.crypto.encrypt(nid);
      data.nationalIdHash = hash;
      data.nationalIdLast4 = this.crypto.last4(nid);
      if (body.dateOfBirth === undefined) {
        data.dateOfBirth = new Date(Date.UTC(validation.birthYear!, validation.birthMonth! - 1, validation.birthDay!));
      }
    }

    try {
      const profile = await this.prisma.captainProfile.update({
        where: { userId: user.id },
        data,
        select: {
          id: true,
          userId: true,
          status: true,
          dateOfBirth: true,
          governorate: true,
          licenseNumber: true,
          vehicleRegistrationNumber: true,
          nationalIdLast4: true,
        },
      });
      return profile;
    } catch (err) {
      if (err instanceof PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictException({ code: 'NATIONAL_ID_DUPLICATE', message: 'National ID is already registered' });
      }
      throw err;
    }
  }

  @Post('location') async location(@CurrentUser() user: { id: string }, @Body() body: LocationDto) {
    const profile = await this.prisma.captainProfile.findUnique({ where: { userId: user.id }, select: { status: true } });
    if (!profile || profile.status !== 'ACTIVE') return { updated: false, reason: 'Captain is not approved' };
    return { updated: await this.redis.updateCaptainLocation(user.id, body.latitude, body.longitude) };
  }

  @Get('wallet') wallet(@CurrentUser() user: { id: string }) {
    return this.prisma.wallet.findUnique({ where: { userId: user.id }, include: { user: { select: { walletTransactions: { orderBy: { createdAt: 'desc' }, take: 50 } } } } });
  }
}

const documentFields = {
  identity: 'nationalIdDocument',
  license: 'licenseDocument',
  vehicle: 'vehicleDocument',
} as const;