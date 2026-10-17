import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class GoogleLoginDto {
  @IsString() @MinLength(10) idToken: string;
  @IsIn(['CLIENT', 'CAPTAIN']) role: 'CLIENT' | 'CAPTAIN';
  @IsOptional() @IsString() vehicleType?: string;
  @IsOptional() @IsString() vehiclePlate?: string;
}
