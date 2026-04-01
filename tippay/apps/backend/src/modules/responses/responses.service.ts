import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { CreateResponseDto } from './dto/create-response.dto';

@Injectable()
export class ResponsesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Create a thank-you response from a worker to a tipper.
   * One response per tip, worker must own the tip.
   */
  async createResponse(workerId: string, dto: CreateResponseDto) {
    // Verify the tip exists and belongs to this worker
    const tip = await this.prisma.tip.findUnique({
      where: { id: dto.tipId },
      select: { id: true, providerId: true, status: true },
    });

    if (!tip) throw new NotFoundException('Tip not found');
    if (tip.providerId !== workerId) {
      throw new BadRequestException('You can only respond to your own tips');
    }
    if (tip.status === 'INITIATED' || tip.status === 'FAILED') {
      throw new BadRequestException('Cannot respond to an unpaid tip');
    }

    // Check for existing response
    const existing = await this.prisma.workerResponse.findUnique({
      where: { tipId: dto.tipId },
    });
    if (existing) {
      throw new ConflictException('You have already responded to this tip');
    }

    // Validate type-specific fields
    if (dto.type === 'emoji' && !dto.emoji) {
      throw new BadRequestException('Emoji is required for emoji responses');
    }
    if ((dto.type === 'voice' || dto.type === 'video') && !dto.mediaUrl) {
      throw new BadRequestException('Media URL is required for voice/video responses');
    }

    return this.prisma.workerResponse.create({
      data: {
        tipId: dto.tipId,
        workerId,
        type: dto.type,
        emoji: dto.emoji,
        mediaUrl: dto.mediaUrl,
      },
    });
  }

  /**
   * Get the response for a specific tip (public — shown to tipper).
   */
  async getResponseForTip(tipId: string) {
    return this.prisma.workerResponse.findUnique({
      where: { tipId },
      select: {
        id: true,
        type: true,
        emoji: true,
        mediaUrl: true,
        createdAt: true,
      },
    });
  }
}
