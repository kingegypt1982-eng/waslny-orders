import { Module } from '@nestjs/common';
import { CaptainsController } from './captains.controller';

@Module({ controllers: [CaptainsController] })
export class CaptainsModule {}