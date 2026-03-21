import {
  Injectable,
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Inject,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { RedisService } from '../../modules/redis/redis.service';

export const RATE_LIMIT_KEY = 'rate_limit';

export interface RateLimitOptions {
  /** Max requests per window */
  limit: number;
  /** Window in seconds */
  windowSeconds: number;
}

/** Decorator to set rate limit on a route */
export function RateLimit(options: RateLimitOptions): MethodDecorator & ClassDecorator {
  return (target: any, key?: string | symbol, descriptor?: PropertyDescriptor) => {
    if (descriptor) {
      Reflect.defineMetadata(RATE_LIMIT_KEY, options, descriptor.value);
    } else {
      Reflect.defineMetadata(RATE_LIMIT_KEY, options, target);
    }
    return descriptor ?? target;
  };
}

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(RedisService) private readonly redis: RedisService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const options = this.reflector.get<RateLimitOptions>(
      RATE_LIMIT_KEY,
      context.getHandler(),
    ) ?? this.reflector.get<RateLimitOptions>(RATE_LIMIT_KEY, context.getClass());

    if (!options) return true;

    const request = context.switchToHttp().getRequest<Request>();
    const ip = request.ip || request.socket.remoteAddress || 'unknown';
    const route = `${request.method}:${request.route?.path || request.url}`;
    const key = `ratelimit:${route}:${ip}`;

    const current = await this.redis.incr(key);
    if (current === 1) {
      // First request in window — set expiry
      await this.redis.setex(key, options.windowSeconds, '1');
    }

    if (current > options.limit) {
      const ttl = await this.redis.ttl(key);
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          message: 'Too many requests',
          retryAfter: ttl,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    return true;
  }
}
