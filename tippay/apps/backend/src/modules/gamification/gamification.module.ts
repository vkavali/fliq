import { Module, OnModuleInit } from '@nestjs/common';
import { GamificationController } from './gamification.controller';
import { GamificationService } from './gamification.service';

@Module({
  controllers: [GamificationController],
  providers: [GamificationService],
  exports: [GamificationService],
})
export class GamificationModule implements OnModuleInit {
  constructor(private readonly gamification: GamificationService) {}

  async onModuleInit() {
    // Seed badges on startup (idempotent)
    await this.gamification.seedBadges();
  }
}
