import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS_CLIENT } from './redis.module';

@Injectable()
export class RedisService {
  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  async get(key: string): Promise<string | null> {
    return this.redis.get(key);
  }

  async set(key: string, value: string): Promise<'OK'> {
    return this.redis.set(key, value);
  }

  /** Set with expiry in seconds. */
  async setex(key: string, seconds: number, value: string): Promise<'OK'> {
    return this.redis.setex(key, seconds, value);
  }

  async del(key: string): Promise<number> {
    return this.redis.del(key);
  }

  /** Increment and return new value. */
  async incr(key: string): Promise<number> {
    return this.redis.incr(key);
  }

  /** Set if not exists. Returns 'OK' if set, null if key already existed. */
  async setnx(key: string, value: string, expirySeconds?: number): Promise<boolean> {
    if (expirySeconds) {
      const result = await this.redis.set(key, value, 'EX', expirySeconds, 'NX');
      return result === 'OK';
    }
    const result = await this.redis.setnx(key, value);
    return result === 1;
  }

  /** Get TTL of a key in seconds. Returns -2 if key does not exist, -1 if no expiry. */
  async ttl(key: string): Promise<number> {
    return this.redis.ttl(key);
  }

  /** Check connection health. */
  async ping(): Promise<string> {
    return this.redis.ping();
  }
}
