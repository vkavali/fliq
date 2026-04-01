import { Module } from '@nestjs/common';
import { TipSessionsController } from './tip-sessions.controller';
import { TipSessionsService } from './tip-sessions.service';

@Module({
  controllers: [TipSessionsController],
  providers: [TipSessionsService],
  exports: [TipSessionsService],
})
export class TipSessionsModule {}
