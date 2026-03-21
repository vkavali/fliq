import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Observable, of } from 'rxjs';
import { tap } from 'rxjs/operators';
import { Request } from 'express';
import { RedisService } from '../../modules/redis/redis.service';

const IDEMPOTENCY_TTL = 86400; // 24 hours
const IDEMPOTENCY_HEADER = 'idempotency-key';

/**
 * Redis-backed idempotency interceptor.
 * If an Idempotency-Key header is present, it caches the response
 * and returns the cached result for duplicate requests within 24h.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly redis: RedisService) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<unknown>> {
    const request = context.switchToHttp().getRequest<Request>();
    const idempotencyKey = request.headers[IDEMPOTENCY_HEADER] as string | undefined;

    if (!idempotencyKey || request.method === 'GET') {
      return next.handle();
    }

    const cacheKey = `idempotency:${idempotencyKey}`;

    // Check for existing response
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return of(JSON.parse(cached));
    }

    // Try to acquire the key (prevent concurrent duplicates)
    const acquired = await this.redis.setnx(cacheKey, 'processing', IDEMPOTENCY_TTL);
    if (!acquired) {
      throw new HttpException(
        'Request with this idempotency key is already being processed',
        HttpStatus.CONFLICT,
      );
    }

    return next.handle().pipe(
      tap(async (response) => {
        await this.redis.setex(cacheKey, IDEMPOTENCY_TTL, JSON.stringify(response));
      }),
    );
  }
}
