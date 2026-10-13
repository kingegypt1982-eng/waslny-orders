import { Module } from '@nestjs/common';
import { KashierClient } from './kashier.client';
import { TopUpsController } from './topups.controller';
import { TopUpsService } from './topups.service';
import { TopupsScheduler } from './topups.scheduler';
import { WebhooksController } from './webhooks.controller';

@Module({
  controllers: [TopUpsController, WebhooksController],
  providers: [TopUpsService, TopupsScheduler, { provide: KashierClient, useFactory: () => KashierClient.fromEnv() }],
  exports: [TopUpsService],
})
export class TopupsModule {}
