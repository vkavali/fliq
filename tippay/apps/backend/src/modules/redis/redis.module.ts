import { Global, Module } from '@nestjs/common';
import { RedisService } from './redis.service';

/**
 * Global cache module using in-memory store.
 * When ready to scale to multiple instances, swap RedisService
 * back to ioredis-backed implementation and add REDIS_CLIENT provider.
 */
@Global()
@Module({
  providers: [RedisService],
  exports: [RedisService],
})
export class RedisModule {}
