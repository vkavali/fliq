import {
  Injectable,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '@tippay/database';
import { WalletType, LedgerEntryType } from '@tippay/shared';
import { RazorpayService } from '../payments/razorpay.service';
import { WalletsService } from '../wallets/wallets.service';
import { RequestPayoutDto } from './dto/request-payout.dto';

@Injectable()
export class PayoutsService {
  private readonly logger = new Logger(PayoutsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
    private readonly wallets: WalletsService,
  ) {}

  async requestPayout(userId: string, dto: RequestPayoutDto) {
    // Verify provider exists and has fund account set up
    const provider = await this.prisma.provider.findUnique({
      where: { id: userId },
    });
    if (!provider) {
      throw new BadRequestException('Provider profile not found');
    }
    if (!provider.razorpayFundAccountId) {
      throw new BadRequestException('Fund account not set up. Complete KYC first.');
    }

    // Check wallet balance
    const wallet = await this.wallets.getOrCreateWallet(userId, WalletType.PROVIDER_EARNINGS);
    if (wallet.balancePaise < BigInt(dto.amountPaise)) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    const mode = dto.mode || 'IMPS';

    // Create payout record
    const payout = await this.prisma.payout.create({
      data: {
        providerId: userId,
        amountPaise: BigInt(dto.amountPaise),
        mode,
        status: 'INITIATED',
        gateway: 'razorpay',
      },
    });

    // Debit provider wallet
    const transaction = await this.prisma.transaction.create({
      data: {
        type: 'PAYOUT',
        referenceId: null,
        fromWalletId: wallet.id,
        amountPaise: BigInt(dto.amountPaise),
        status: 'PENDING',
        gateway: 'razorpay',
      },
    });

    await this.wallets.debitWallet(
      wallet.id,
      BigInt(dto.amountPaise),
      transaction.id,
      `Payout ${payout.id}`,
    );

    // Initiate RazorpayX payout
    try {
      const rzpPayout = await this.razorpay.createPayout(
        provider.razorpayFundAccountId,
        dto.amountPaise,
        mode,
      );

      await this.prisma.payout.update({
        where: { id: payout.id },
        data: { gatewayPayoutId: rzpPayout?.id },
      });

      this.logger.log(`Payout initiated: ${payout.id}, RazorpayX: ${rzpPayout?.id}`);
    } catch (error) {
      this.logger.error(`RazorpayX payout failed for ${payout.id}`, error);
      // Mark payout as failed, refund wallet
      await this.prisma.payout.update({
        where: { id: payout.id },
        data: { status: 'FAILED', failureReason: String(error) },
      });
      await this.wallets.creditWallet(
        wallet.id,
        BigInt(dto.amountPaise),
        transaction.id,
        `Payout reversal ${payout.id}`,
      );
      throw new BadRequestException('Payout initiation failed. Amount refunded to wallet.');
    }

    return {
      payoutId: payout.id,
      amountPaise: dto.amountPaise,
      mode,
      status: 'INITIATED',
    };
  }

  async getPayoutHistory(providerId: string, page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;
    const [payouts, total] = await Promise.all([
      this.prisma.payout.findMany({
        where: { providerId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.payout.count({ where: { providerId } }),
    ]);
    return { payouts, total, page, limit };
  }
}
