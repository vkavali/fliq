import { Controller, Post, Delete, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PushNotificationsService } from './push-notifications.service';
import { RegisterFcmTokenDto } from './dto/register-fcm-token.dto';

@ApiTags('Push Notifications')
@Controller('notifications')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class PushNotificationsController {
  constructor(private readonly pushService: PushNotificationsService) {}

  @Post('fcm-token')
  @ApiOperation({ summary: 'Register or update FCM device token' })
  async registerToken(
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterFcmTokenDto,
  ) {
    await this.pushService.registerToken(userId, dto.token, dto.platform);
    return { message: 'Token registered' };
  }

  @Delete('fcm-token')
  @ApiOperation({ summary: 'Remove FCM device token (on logout)' })
  async removeToken(@CurrentUser('id') userId: string) {
    await this.pushService.removeToken(userId);
    return { message: 'Token removed' };
  }
}
