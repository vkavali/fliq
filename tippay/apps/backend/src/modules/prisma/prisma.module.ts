import { Global, Module } from '@nestjs/common';
import { PrismaService } from '@fliq/database';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
