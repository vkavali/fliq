import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { envValidationSchema } from './config/env.validation';
import { PrismaModule } from './modules/prisma/prisma.module';
import { RedisModule } from './modules/redis/redis.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ProvidersModule } from './modules/providers/providers.module';
import { TipsModule } from './modules/tips/tips.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { WalletsModule } from './modules/wallets/wallets.module';
import { PayoutsModule } from './modules/payouts/payouts.module';
import { QrCodesModule } from './modules/qrcodes/qrcodes.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AdminModule } from './modules/admin/admin.module';
import { OutboxModule } from './modules/outbox/outbox.module';
import { PaymentLinksModule } from './modules/payment-links/payment-links.module';
import { GamificationModule } from './modules/gamification/gamification.module';
import { TipPoolsModule } from './modules/tip-pools/tip-pools.module';
import { PushNotificationsModule } from './modules/push-notifications/push-notifications.module';
import { RecurringTipsModule } from './modules/recurring-tips/recurring-tips.module';
import { BusinessModule } from './modules/business/business.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [
        '../../.env',       // monorepo root
        '../../.env.local', // local overrides
      ],
      validationSchema: envValidationSchema,
    }),
    PrismaModule,
    RedisModule,
    AuthModule,
    UsersModule,
    ProvidersModule,
    WalletsModule,
    PaymentsModule,
    TipsModule,
    PayoutsModule,
    QrCodesModule,
    NotificationsModule,
    AdminModule,
    OutboxModule,
    PaymentLinksModule,
    GamificationModule,
    TipPoolsModule,
    PushNotificationsModule,
    RecurringTipsModule,
    BusinessModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
