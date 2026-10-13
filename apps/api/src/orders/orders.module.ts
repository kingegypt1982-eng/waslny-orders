import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrderEventsModule } from '../order-events/order-events.module';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({ imports: [NotificationsModule, OrderEventsModule], controllers: [OrdersController], providers: [OrdersService], exports: [OrdersService] })
export class OrdersModule {}