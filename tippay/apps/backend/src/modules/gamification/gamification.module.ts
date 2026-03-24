import { Module, OnModuleInit, Logger } from '@nestjs/common';
import { GamificationController } from './gamification.controller';
import { GamificationService } from './gamification.service';

@Module({
  controllers: [GamificationController],
  providers: [GamificationService],
  exports: [GamificationService],
})
export class GamificationModule implements OnModuleInit {
  private readonly logger = new Logger(GamificationModule.name);

  constructor(private readonly gamification: GamificationService) {}

  async onModuleInit() {
    try {
      await this.gamification.seedBadges();
    } catch (error: any) {
      this.logger.warn(
        `Badge seeding skipped — tables may not exist yet. Run prisma migrate. Error: ${error?.message ?? error}`,
      );
    }
  }
}
