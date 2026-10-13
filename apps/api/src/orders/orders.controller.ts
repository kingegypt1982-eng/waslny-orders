import { Body, Controller, Get, Param, Patch, Post, Query, StreamableFile, UseGuards, UseInterceptors, UploadedFile } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { OrderStatus } from '@prisma/client';
import { createReadStream } from 'fs';
import { memoryStorage } from 'multer';
import { basename } from 'path';
import { CurrentUser, Roles } from '../auth/auth.decorators';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { CreateOrderDto } from './dto/create-order.dto';
import { ProofNoteDto } from './dto/proof-note.dto';
import { QuoteOrderDto } from './dto/quote-order.dto';
import { UpdateStatusDto } from './dto/update-status.dto';
import { PROOF_MAX_BYTES } from './proof-upload';
import { OrdersService } from './orders.service';

@ApiTags('Orders')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Post('quote') @Roles('CLIENT') quote(@Body() body: QuoteOrderDto) { return this.orders.quote(body); }
  @Post() @Roles('CLIENT') create(@CurrentUser() user: { id: string }, @Body() body: CreateOrderDto) { return this.orders.create(user.id, body); }
  @Get() list(@CurrentUser() user: { id: string; role: 'CLIENT' | 'CAPTAIN' | 'ADMIN' }) { return this.orders.listForUser(user); }
  @Get('available') @Roles('CAPTAIN') available(@Query('latitude') latitude: string, @Query('longitude') longitude: string) {
    return this.orders.available(Number(latitude), Number(longitude));
  }
  @Post(':id/accept') @Roles('CAPTAIN') accept(@Param('id') id: string, @CurrentUser() user: { id: string }) { return this.orders.accept(id, user.id); }
  @Post(':id/release') @Roles('CAPTAIN') release(@Param('id') id: string, @CurrentUser() user: { id: string }) { return this.orders.release(id, user.id); }
  @Patch(':id/status') @Roles('CAPTAIN') transition(@Param('id') id: string, @CurrentUser() user: { id: string }, @Body() body: UpdateStatusDto) {
    return this.orders.transition(id, user.id, body.status as OrderStatus);
  }
  @Post(':id/complete') @Roles('CLIENT') complete(@Param('id') id: string, @CurrentUser() user: { id: string }) { return this.orders.complete(id, user.id); }
  @Post(':id/cancel') @Roles('CLIENT') cancel(@Param('id') id: string, @CurrentUser() user: { id: string }) { return this.orders.cancel(id, user.id); }
  @Post(':id/proof/pickup') @Roles('CAPTAIN')
  @UseInterceptors(FileInterceptor('photo', { storage: memoryStorage(), limits: { fileSize: PROOF_MAX_BYTES } }))
  submitPickupProof(
    @Param('id') id: string,
    @CurrentUser() user: { id: string },
    @Body() body: ProofNoteDto,
    @UploadedFile() photo?: Express.Multer.File,
  ) {
    return this.orders.submitPickupProof(id, user.id, toPhotoInput(photo), body?.note);
  }
  @Post(':id/proof/delivery') @Roles('CAPTAIN')
  @UseInterceptors(FileInterceptor('photo', { storage: memoryStorage(), limits: { fileSize: PROOF_MAX_BYTES } }))
  submitDeliveryProof(
    @Param('id') id: string,
    @CurrentUser() user: { id: string },
    @Body() body: ProofNoteDto,
    @UploadedFile() photo?: Express.Multer.File,
  ) {
    return this.orders.submitDeliveryProof(id, user.id, toPhotoInput(photo), body?.note);
  }
  @Get(':id/proofs') proofs(@Param('id') id: string, @CurrentUser() user: { id: string; role: 'CLIENT' | 'CAPTAIN' | 'ADMIN' }) {
    return this.orders.proofsForUser(id, user);
  }
  @Get(':id/proofs/:proofId/photo')
  async proofPhoto(
    @Param('id') id: string,
    @Param('proofId') proofId: string,
    @CurrentUser() user: { id: string; role: 'CLIENT' | 'CAPTAIN' | 'ADMIN' },
  ) {
    const file = await this.orders.proofPhotoForUser(id, proofId, user);
    return new StreamableFile(createReadStream(file.path), {
      type: file.mimeType,
      disposition: `inline; filename="${basename(file.path)}"`,
    });
  }
  @Get(':id/events') events(@Param('id') id: string, @CurrentUser() user: { id: string; role: 'CLIENT' | 'CAPTAIN' | 'ADMIN' }) { return this.orders.eventsForUser(id, user); }
  @Get(':id') get(@Param('id') id: string, @CurrentUser() user: { id: string; role: 'CLIENT' | 'CAPTAIN' | 'ADMIN' }) { return this.orders.getForUser(id, user); }
}

function toPhotoInput(photo?: Express.Multer.File) {
  if (!photo) return undefined;
  return { buffer: photo.buffer, size: photo.size };
}