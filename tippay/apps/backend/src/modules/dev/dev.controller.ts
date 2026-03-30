import { Controller, Get, Post, Logger } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { DevService } from './dev.service';

/**
 * Dev/test endpoints — only functional when DEV_BYPASS_ENABLED=true.
 * Attempting to call these with bypass disabled returns 403.
 */
@ApiTags('Dev (bypass required)')
@Controller('dev')
export class DevController {
  private readonly logger = new Logger(DevController.name);

  constructor(private readonly dev: DevService) {}

  @Get('status')
  @ApiOperation({ summary: 'Show test account status and bypass state' })
  getStatus() {
    return this.dev.getStatus();
  }

  @Post('seed')
  @ApiOperation({ summary: 'Create/refresh test accounts, wallets, tips, jar, pool, business' })
  seed() {
    this.logger.warn('[DEV] /dev/seed called');
    return this.dev.seedTestData();
  }
}
