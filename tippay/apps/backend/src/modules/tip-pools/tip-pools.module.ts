import { Module } from '@nestjs/common';
import { TipPoolsController } from './tip-pools.controller';
import { TipPoolsService } from './tip-pools.service';
import { WalletsModule } from '../wallets/wallets.module';

@Module({
  imports: [WalletsModule],
  controllers: [TipPoolsController],
  providers: [TipPoolsService],
  exports: [TipPoolsService],
})
export class TipPoolsModule {}
