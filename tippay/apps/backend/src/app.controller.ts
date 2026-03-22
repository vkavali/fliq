import { Controller, Get, Res } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiExcludeEndpoint } from '@nestjs/swagger';
import { Response } from 'express';

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
}
