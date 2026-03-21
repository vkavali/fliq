import {
  Controller,
  Post,
  Headers,
  RawBody,
  HttpCode,
  HttpStatus,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiExcludeEndpoint } from '@nestjs/swagger';
import { PrismaService } from '@tippay/database';
import { RazorpayService } from './razorpay.service';
import { PaymentsService } from './payments.service';

@ApiTags('Webhooks')
@Controller('webhooks')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(
    private readonly razorpay: RazorpayService,
    private readonly payments: PaymentsService,
    private readonly prisma: PrismaService,
  ) {}

  @Post('razorpay')
  @HttpCode(HttpStatus.OK)
  @ApiExcludeEndpoint()
  async handleRazorpayWebhook(
    @RawBody() rawBody: Buffer,
    @Headers('x-razorpay-signature') signature: string,
  ) {
    const body = rawBody.toString('utf-8');

    // Verify signature
    if (!signature || !this.razorpay.verifyWebhookSignature(body, signature)) {
      throw new BadRequestException('Invalid webhook signature');
    }

    const event = JSON.parse(body);
    const eventId = event.event_id || event.id;
    const eventType = event.event;

    // Idempotent: check if already processed
    const existing = await this.prisma.webhookEvent.findUnique({
      where: { eventId },
    });
    if (existing?.processed) {
      this.logger.log(`Webhook ${eventId} already processed, skipping`);
      return { status: 'already_processed' };
    }

    // Store event
    if (!existing) {
      await this.prisma.webhookEvent.create({
        data: {
          eventId,
          gateway: 'razorpay',
          eventType,
          payload: event,
        },
      });
    }

    // Process event (synchronous for MVP; move to queue in Phase 2)
    try {
      await this.payments.handleWebhookEvent(eventType, event.payload);

      await this.prisma.webhookEvent.update({
        where: { eventId },
        data: { processed: true, processedAt: new Date() },
      });
    } catch (err) {
      this.logger.error(`Failed to process webhook ${eventId}: ${err}`);
      // Return 200 anyway to prevent Razorpay retries flooding us.
      // The event is stored and can be reprocessed.
    }

    return { status: 'ok' };
  }
}
