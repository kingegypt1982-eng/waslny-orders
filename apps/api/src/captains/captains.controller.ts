import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { BadRequestException, Param, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsNumber, Max, Min } from 'class-validator';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { dirname, join } from 'path';
import { memoryStorage } from 'multer';
import { CurrentUser, Roles } from '../auth/auth.decorators';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.module';

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
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  @Get('me') profile(@CurrentUser() user: { id: string }) {
    return this.prisma.captainProfile.findUnique({ where: { userId: user.id }, include: { user: { select: { id: true, name: true, email: true, phone: true, wallet: true } } } });
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