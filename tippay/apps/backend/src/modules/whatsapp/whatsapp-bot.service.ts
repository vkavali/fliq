import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { formatPaise, WalletType, PayoutMode } from '@fliq/shared';
import { WhatsAppService } from './whatsapp.service';
import { WalletsService } from '../wallets/wallets.service';
import { PayoutsService } from '../payouts/payouts.service';
import { RedisService } from '../redis/redis.service';

// Redis TTL for pending payout confirmation state (5 minutes)
const PAYOUT_PENDING_TTL_S = 300;

/**
 * WhatsApp Bot Service.
 * Handles provider commands and customer interactions over WhatsApp.
 *
 * Provider commands (matched by incoming phone → User.phone):
 *   balance / bal  — current wallet balance
 *   earnings       — last 7 days earnings summary
 *   tips           — last 5 tips received
 *   payout         — initiate payout (interactive confirm flow)
 *   qr             — send QR code image
 *   help           — list commands
 *
 * Interactive replies:
 *   confirm_payout / cancel_payout — from payout confirmation flow
 */
@Injectable()
export class WhatsAppBotService {
  private readonly logger = new Logger(WhatsAppBotService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly whatsapp: WhatsAppService,
    private readonly wallets: WalletsService,
    @Inject(forwardRef(() => PayoutsService)) private readonly payouts: PayoutsService,
    private readonly redis: RedisService,
  ) {}

  /**
   * Handle an incoming text message from a WhatsApp user.
   */
  async handleTextMessage(from: string, text: string, messageId: string): Promise<void> {
    await this.whatsapp.markMessageRead(messageId);

    const normalized = text.trim().toLowerCase();

    // Look up user by phone number (strip + prefix for comparison)
    const phoneDigits = from.replace(/\D/g, '');
    const user = await this.prisma.user.findFirst({
      where: {
        phone: { in: [phoneDigits, `+${phoneDigits}`] },
        status: 'ACTIVE',
      },
      include: { providerProfile: true },
    });

    if (!user) {
      await this.whatsapp.sendTextMessage(
        from,
        `Hi! I'm the Fliq tipping bot. You don't have an account yet.\n\nVisit fliq.co.in to get started as a provider and start receiving tips! 🙏`,
      );
      return;
    }

    if (user.type === 'PROVIDER' && user.providerProfile) {
      await this.handleProviderCommand(user, user.providerProfile, from, normalized);
    } else {
      await this.whatsapp.sendTextMessage(
        from,
        `Hi ${user.name ?? 'there'}! 👋\n\nYou're registered as a customer on Fliq. Use our app to send tips to your favourite service providers.\n\nVisit fliq.co.in to tip someone now!`,
      );
    }
  }

  /**
   * Handle an interactive button reply (e.g., payout confirmation).
   */
  async handleInteractiveReply(from: string, buttonId: string, messageId: string): Promise<void> {
    await this.whatsapp.markMessageRead(messageId);

    if (buttonId === 'confirm_payout') {
      await this.processPayout(from);
    } else if (buttonId === 'cancel_payout') {
      await this.redis.del(`wa:payout:${from}`);
      await this.whatsapp.sendTextMessage(from, '❌ Payout cancelled.');
    }
  }

  private async handleProviderCommand(
    user: { id: string; name: string | null; phone: string | null },
    provider: { id: string; qrCodeUrl: string | null; razorpayFundAccountId: string | null },
    from: string,
    command: string,
  ): Promise<void> {
    switch (command) {
      case 'balance':
      case 'bal':
        await this.cmdBalance(user.id, from);
        break;
      case 'earnings':
        await this.cmdEarnings(user.id, from);
        break;
      case 'tips':
        await this.cmdTips(user.id, from);
        break;
      case 'payout':
        await this.cmdPayout(user, provider, from);
        break;
      case 'qr':
        await this.cmdQr(user, provider, from);
        break;
      case 'help':
        await this.cmdHelp(user.name, from);
        break;
      default:
        await this.whatsapp.sendTextMessage(
          from,
          `I didn't understand *${command}*. Send *help* to see available commands.`,
        );
    }
  }

  private async cmdBalance(userId: string, from: string): Promise<void> {
    const wallet = await this.wallets.getOrCreateWallet(userId, WalletType.PROVIDER_EARNINGS);
    const balance = formatPaise(Number(wallet.balancePaise));
    await this.whatsapp.sendTextMessage(from, `💰 *Your Fliq Balance*\n\n${balance}`);
  }

  private async cmdEarnings(userId: string, from: string): Promise<void> {
    const since = new Date();
    since.setDate(since.getDate() - 7);

    const result = await this.prisma.tip.aggregate({
      where: {
        providerId: userId,
        status: { in: ['PAID', 'SETTLED'] },
        createdAt: { gte: since },
      },
      _sum: { netAmountPaise: true, amountPaise: true },
      _count: true,
    });

    const gross = formatPaise(Number(result._sum.amountPaise ?? 0));
    const net = formatPaise(Number(result._sum.netAmountPaise ?? 0));
    const count = result._count;

    await this.whatsapp.sendTextMessage(
      from,
      `📊 *Last 7 Days Earnings*\n\nTips received: ${count}\nGross: ${gross}\nNet (after commission): ${net}`,
    );
  }

  private async cmdTips(userId: string, from: string): Promise<void> {
    const tips = await this.prisma.tip.findMany({
      where: { providerId: userId, status: { in: ['PAID', 'SETTLED'] } },
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: { customer: { select: { name: true } } },
    });

    if (tips.length === 0) {
      await this.whatsapp.sendTextMessage(from, `You haven't received any tips yet. Share your Fliq link to start! 🚀`);
      return;
    }

    const lines = tips.map((t, i) => {
      const amount = formatPaise(Number(t.amountPaise));
      const from_ = t.customer?.name ?? 'Anonymous';
      const stars = t.rating ? '⭐'.repeat(t.rating) : '';
      const msg = t.message ? `\n   "${t.message}"` : '';
      const date = t.createdAt.toLocaleDateString('en-IN');
      return `${i + 1}. ${amount} from ${from_} ${stars} (${date})${msg}`;
    });

    await this.whatsapp.sendTextMessage(
      from,
      `🧾 *Last ${tips.length} Tips Received*\n\n${lines.join('\n\n')}`,
    );
  }

  private async cmdPayout(
    user: { id: string; name: string | null },
    provider: { razorpayFundAccountId: string | null },
    from: string,
  ): Promise<void> {
    if (!provider.razorpayFundAccountId) {
      await this.whatsapp.sendTextMessage(
        from,
        `⚠️ *KYC Required*\n\nYou need to complete KYC before requesting a payout.\n\nOpen the Fliq app and complete your bank account details.`,
      );
      return;
    }

    const wallet = await this.wallets.getOrCreateWallet(user.id, WalletType.PROVIDER_EARNINGS);
    const balance = wallet.balancePaise;

    if (balance < 10000n) {
      const fmt = formatPaise(Number(balance));
      await this.whatsapp.sendTextMessage(
        from,
        `💸 Your balance is ${fmt}.\n\nMinimum payout amount is ₹100. Keep collecting tips! 🚀`,
      );
      return;
    }

    const fmt = formatPaise(Number(balance));

    // Store pending state in Redis (5 min TTL)
    await this.redis.setex(`wa:payout:${from}`, PAYOUT_PENDING_TTL_S, String(Number(balance)));

    await this.whatsapp.sendInteractiveButtons(
      from,
      `Your available balance is *${fmt}*.\n\nDo you want to initiate a payout of the full amount?`,
      [
        { id: 'confirm_payout', title: '✅ Confirm' },
        { id: 'cancel_payout', title: '❌ Cancel' },
      ],
      'Payout Request',
    );
  }

  private async cmdQr(
    user: { id: string; name: string | null },
    provider: { qrCodeUrl: string | null },
    from: string,
  ): Promise<void> {
    // Try provider.qrCodeUrl first, then check qr_codes table for an active code
    let qrUrl = provider.qrCodeUrl;

    if (!qrUrl) {
      const qr = await this.prisma.qrCode.findFirst({
        where: { providerId: user.id, isActive: true },
        orderBy: { createdAt: 'desc' },
      });
      qrUrl = qr?.qrImageUrl ?? null;
    }

    if (!qrUrl) {
      await this.whatsapp.sendTextMessage(
        from,
        `📷 You don't have a QR code yet.\n\nOpen the Fliq app to generate your QR code.`,
      );
      return;
    }

    await this.whatsapp.sendImageMessage(
      from,
      qrUrl,
      `Your Fliq QR Code${user.name ? ` — ${user.name}` : ''}. Share this for customers to tip you!`,
    );
  }

  private async cmdHelp(name: string | null, from: string): Promise<void> {
    const greeting = name ? `Hi ${name}! 👋` : 'Hi there! 👋';
    await this.whatsapp.sendTextMessage(
      from,
      `${greeting}\n\n*Fliq Provider Commands*\n\n` +
        `💰 *balance* — Check your wallet balance\n` +
        `📊 *earnings* — Last 7 days summary\n` +
        `🧾 *tips* — Last 5 tips received\n` +
        `💸 *payout* — Initiate a payout\n` +
        `📷 *qr* — Get your QR code\n` +
        `❓ *help* — Show this menu\n\n` +
        `_Powered by Fliq.co.in_`,
    );
  }

  private async processPayout(from: string): Promise<void> {
    const pendingAmountStr = await this.redis.get(`wa:payout:${from}`);
    if (!pendingAmountStr) {
      await this.whatsapp.sendTextMessage(
        from,
        `⏱️ Payout session expired. Send *payout* to start again.`,
      );
      return;
    }

    await this.redis.del(`wa:payout:${from}`);

    // Look up user by phone
    const phoneDigits = from.replace(/\D/g, '');
    const user = await this.prisma.user.findFirst({
      where: {
        phone: { in: [phoneDigits, `+${phoneDigits}`] },
        status: 'ACTIVE',
      },
    });

    if (!user) {
      await this.whatsapp.sendTextMessage(from, `⚠️ Could not find your account. Please try again.`);
      return;
    }

    try {
      const amountPaise = parseInt(pendingAmountStr, 10);
      const result = await this.payouts.requestPayout(user.id, { amountPaise, mode: PayoutMode.IMPS });
      const fmt = formatPaise(result.amountPaise);
      await this.whatsapp.sendTextMessage(
        from,
        `✅ *Payout Initiated!*\n\n${fmt} via IMPS\nPayout ID: ${result.payoutId}\n\nYou'll receive the amount in your bank account within 30 minutes.`,
      );
    } catch (error) {
      const msg = (error as Error).message || 'Unknown error';
      await this.whatsapp.sendTextMessage(from, `❌ Payout failed: ${msg}`);
    }
  }
}
