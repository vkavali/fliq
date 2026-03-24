import { Controller, Get, Param, Res } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiExcludeEndpoint } from '@nestjs/swagger';
import { Response } from 'express';
import { join } from 'path';
import { PrismaService } from '@fliq/database';

@ApiTags('Health')
@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiExcludeEndpoint()
  root(@Res() res: Response) {
    res.redirect('/app/');
  }

  @Get('health')
  @ApiOperation({ summary: 'Health check' })
  async health() {
    let db = 'unknown';
    try {
      await this.prisma.$queryRawUnsafe('SELECT 1');
      db = 'connected';
    } catch {
      db = 'disconnected';
    }
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'fliq-backend',
      db,
    };
  }

  @Get('health/db')
  @ApiExcludeEndpoint()
  async dbHealth() {
    const checks: Record<string, string> = {};
    const tables = ['users', 'providers', 'payment_links', 'tips', 'qr_codes', 'outbox_events'];
    for (const table of tables) {
      try {
        await this.prisma.$queryRawUnsafe(`SELECT 1 FROM "${table}" LIMIT 1`);
        checks[table] = 'ok';
      } catch (e: any) {
        checks[table] = e.message?.substring(0, 100) || 'error';
      }
    }
    return { timestamp: new Date().toISOString(), tables: checks };
  }

  @Get('tip/:shortCode')
  @ApiExcludeEndpoint()
  tipPage(@Param('shortCode') shortCode: string, @Res() res: Response) {
    res.sendFile('tip.html', { root: join(__dirname, '..', '..', 'web', 'public') });
  }
}
