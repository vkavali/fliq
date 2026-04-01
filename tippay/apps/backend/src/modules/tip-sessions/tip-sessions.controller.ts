import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { TipSessionsService } from './tip-sessions.service';
import { CreateSessionDto } from './dto/create-session.dto';
import { SettleTipDto } from './dto/settle-tip.dto';

@Controller('v5/sessions')
export class TipSessionsController {
  constructor(private readonly tipSessionsService: TipSessionsService) {}

  @Post()
  createSession(@Body() dto: CreateSessionDto) {
    return this.tipSessionsService.createSession(dto);
  }

  @Get(':sessionId')
  getSession(@Param('sessionId') sessionId: string) {
    return this.tipSessionsService.getSession(sessionId);
  }

  @Post('webhook/settle')
  settleWebhook(@Body() dto: SettleTipDto) {
    return this.tipSessionsService.settleWebhook(dto);
  }
}
