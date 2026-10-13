import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async register(input: RegisterDto) {
    if (input.role === 'CAPTAIN' && (!input.vehicleType || !input.vehiclePlate)) {
      throw new ConflictException('Captain vehicle details are required');
    }
    if (await this.prisma.user.findUnique({ where: { email: input.email.toLowerCase() } })) {
      throw new ConflictException('Email is already registered');
    }
    const user = await this.prisma.user.create({
      data: {
        email: input.email.toLowerCase(), name: input.name, phone: input.phone,
        passwordHash: await bcrypt.hash(input.password, 12), role: input.role,
        wallet: { create: {} },
        ...(input.role === 'CAPTAIN' ? {
          captain: { create: {
            nationalIdDocument: input.nationalIdDocument ?? 'PENDING_UPLOAD',
            licenseDocument: input.licenseDocument ?? 'PENDING_UPLOAD',
            vehicleDocument: input.vehicleDocument ?? 'PENDING_UPLOAD',
            vehicleType: input.vehicleType!, vehiclePlate: input.vehiclePlate!,
          } },
        } : {}),
      },
      select: { id: true, email: true, name: true, role: true },
    });
    return this.session(user);
  }

  async login(input: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: input.email.toLowerCase() } });
    if (!user || user.suspendedAt || !(await bcrypt.compare(input.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.session({ id: user.id, email: user.email, name: user.name, role: user.role });
  }

  private async session(user: { id: string; email: string; name: string; role: string }) {
    return { accessToken: await this.jwt.signAsync({ sub: user.id, role: user.role }), user };
  }
}