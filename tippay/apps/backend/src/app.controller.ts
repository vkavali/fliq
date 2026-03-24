import { Controller, Get, Param, Res } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiExcludeEndpoint } from '@nestjs/swagger';
import { Response } from 'express';
import { join } from 'path';

@ApiTags('Health')
@Controller()
export class AppController {
  @Get()
  @ApiExcludeEndpoint()
  root(@Res() res: Response) {
    res.redirect('/app/');
  }

  @Get('health')
  @ApiOperation({ summary: 'Health check' })
  health() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'fliq-backend',
    };
  }

  @Get('tip/:shortCode')
  @ApiExcludeEndpoint()
  tipPage(@Param('shortCode') shortCode: string, @Res() res: Response) {
    res.sendFile('tip.html', { root: join(__dirname, '..', '..', 'web', 'public') });
  }
}
