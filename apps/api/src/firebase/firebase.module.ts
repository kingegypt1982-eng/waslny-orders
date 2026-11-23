import { Module, Global } from '@nestjs/common';
import { FirebaseService } from './firebase.service';
import { ChatService } from './chat.service';
import { ChatScheduler } from './chat.scheduler';

@Global()
@Module({
  providers: [FirebaseService, ChatService, ChatScheduler],
  exports: [FirebaseService, ChatService],
})
export class FirebaseModule {}