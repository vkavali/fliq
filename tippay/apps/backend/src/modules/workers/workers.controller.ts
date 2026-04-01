import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { WorkersService } from './workers.service';
import { RegisterWorkerDto } from './dto/register-worker.dto';
import { CreateGoalDto } from './dto/update-goal.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('v5/workers')
export class WorkersController {
  constructor(private readonly workersService: WorkersService) {}

  @Post('register')
  @UseGuards(JwtAuthGuard)
  register(@Request() req: any, @Body() dto: RegisterWorkerDto) {
    return this.workersService.register(req.user.sub, dto);
  }

  @Get(':workerId')
  getProfile(@Param('workerId') workerId: string) {
    return this.workersService.getProfile(workerId);
  }

  @Get('by-token/:qrToken')
  getProfileByToken(@Param('qrToken') qrToken: string) {
    return this.workersService.getProfileByToken(qrToken);
  }

  @Post(':workerId/qr/rotate')
  @UseGuards(JwtAuthGuard)
  generateQr(@Param('workerId') workerId: string) {
    return this.workersService.generateQr(workerId);
  }

  @Get(':workerId/earnings')
  @UseGuards(JwtAuthGuard)
  getEarnings(@Param('workerId') workerId: string) {
    return this.workersService.getEarnings(workerId);
  }

  @Get(':workerId/goals')
  getGoals(@Param('workerId') workerId: string) {
    return this.workersService.getGoals(workerId);
  }

  @Post(':workerId/goals')
  @UseGuards(JwtAuthGuard)
  createGoal(@Param('workerId') workerId: string, @Body() dto: CreateGoalDto) {
    return this.workersService.createGoal(workerId, dto);
  }

  @Get(':workerId/merit')
  getMerit(@Param('workerId') workerId: string) {
    return this.workersService.getMerit(workerId);
  }
}
