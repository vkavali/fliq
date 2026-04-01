import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { ReputationService } from './reputation.service';

@ApiTags('Reputation')
@Controller('reputation')
export class ReputationController {
  constructor(private readonly reputationService: ReputationService) {}

  @Get(':workerId')
  @ApiOperation({ summary: 'Get reputation score for a worker (public)' })
  async getReputation(
    @Param('workerId', new ParseUUIDPipe()) workerId: string,
  ) {
    return this.reputationService.getReputation(workerId);
  }
}
