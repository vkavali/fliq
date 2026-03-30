import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import * as admin from 'firebase-admin';

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private readonly messaging: admin.messaging.Messaging | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    const serviceAccountBase64 = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_BASE64');
    if (serviceAccountBase64) {
      try {
        const serviceAccount = JSON.parse(
          Buffer.from(serviceAccountBase64, 'base64').toString('utf8'),
        ) as admin.ServiceAccount;

        // Initialize only if no app exists (prevents re-init on hot reload)
        const app = admin.apps.length
          ? admin.app()
          : admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

        this.messaging = admin.messaging(app);
        this.logger.log('Firebase Admin initialized');
      } catch (err) {
        this.logger.error('Failed to initialize Firebase Admin', err);
      }
    } else {
      this.logger.warn('FIREBASE_SERVICE_ACCOUNT_BASE64 not set — push notifications disabled');
    }
  }

  // ── Token management ─────────────────────────────────────────────────────

  async registerToken(userId: string, token: string, platform: string): Promise<void> {
    await this.prisma.fcmToken.upsert({
      where: { userId },
      update: { token, platform },
      create: { userId, token, platform },
    });
  }

  async removeToken(userId: string): Promise<void> {
    await this.prisma.fcmToken.deleteMany({ where: { userId } });
  }

  // ── Send helpers ─────────────────────────────────────────────────────────

  async sendToUser(
    userId: string,
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.messaging) return;

    const fcmToken = await this.prisma.fcmToken.findUnique({ where: { userId } });
    if (!fcmToken) return;

    try {
      await this.messaging.send({
        token: fcmToken.token,
        notification: { title: notification.title, body: notification.body },
        data,
        android: {
          notification: { channelId: 'fliq_tips', priority: 'high' },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error(`FCM send failed for user ${userId}: ${message}`);
      // Remove invalid tokens so we don't keep retrying them
      if (message.includes('registration-token-not-registered') || message.includes('invalid-argument')) {
        await this.removeToken(userId);
      }
    }
  }

  // ── Domain-specific senders ──────────────────────────────────────────────

  async sendTipReceived(
    providerId: string,
    amountPaise: number,
    customerName?: string,
    message?: string,
  ): Promise<void> {
    const rupees = Math.round(amountPaise / 100);
    const from = customerName ? ` from ${customerName}` : '';
    const msgSuffix = message ? `: "${message}"` : '';
    await this.sendToUser(
      providerId,
      { title: '🎉 New Tip!', body: `₹${rupees}${from}${msgSuffix}` },
      { type: 'tip', screen: '/dashboard' },
    );
  }

  async sendPayoutProcessed(providerId: string, amountPaise: number): Promise<void> {
    const rupees = Math.round(amountPaise / 100);
    await this.sendToUser(
      providerId,
      { title: 'Payout Successful ✅', body: `₹${rupees} has been transferred to your account` },
      { type: 'payout', screen: '/payouts' },
    );
  }

  async sendPayoutFailed(providerId: string, amountPaise: number): Promise<void> {
    const rupees = Math.round(amountPaise / 100);
    await this.sendToUser(
      providerId,
      { title: 'Payout Failed ❌', body: `₹${rupees} payout failed. Tap to retry.` },
      { type: 'payout_failed', screen: '/payouts' },
    );
  }

  async sendBadgeEarned(userId: string, badgeName: string): Promise<void> {
    await this.sendToUser(
      userId,
      { title: '🏆 Badge Earned!', body: `You earned the "${badgeName}" badge` },
      { type: 'badge', screen: '/badges' },
    );
  }
}
