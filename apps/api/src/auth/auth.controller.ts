import { Body, Controller, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  // Stricter than the global limit: brute-force protection on credentials endpoints.
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('register') register(@Body() body: RegisterDto) { return this.auth.register(body); }
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('login') login(@Body() body: LoginDto) { return this.auth.login(body); }
}