import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ResponsesService } from './responses.service';
import { CreateResponseDto } from './dto/create-response.dto';

@ApiTags('Responses')
@Controller('responses')
export class ResponsesController {
  constructor(private readonly responsesService: ResponsesService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Send a thank-you response to a tip (worker only)' })
  async createResponse(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateResponseDto,
  ) {
    return this.responsesService.createResponse(userId, dto);
  }

  @Get('tip/:tipId')
  @ApiOperation({ summary: 'Get response for a tip (public)' })
  async getResponseForTip(
    @Param('tipId', new ParseUUIDPipe()) tipId: string,
  ) {
    return this.responsesService.getResponseForTip(tipId);
  }
}
