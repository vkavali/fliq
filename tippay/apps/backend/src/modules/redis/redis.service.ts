import { Injectable, Logger } from '@nestjs/common';

/**
 * In-memory key-value store that replaces Redis for single-instance deployments.
 * Same interface as the original Redis-backed service — swap back to ioredis
 * when scaling to multiple instances.
 */

interface CacheEntry {
  value: string;
  expiresAt: number | null; // epoch ms, null = no expiry
}

@Injectable()
export class RedisService {
  private readonly store = new Map<string, CacheEntry>();
  private readonly logger = new Logger(RedisService.name);
  private cleanupTimer: ReturnType<typeof setInterval>;

  constructor() {
    // Periodic cleanup of expired keys (every 60s)
    this.cleanupTimer = setInterval(() => this.evictExpired(), 60_000);
    this.logger.log('In-memory cache initialized (Redis replacement)');
  }

  onModuleDestroy() {
    clearInterval(this.cleanupTimer);
  }

  async get(key: string): Promise<string | null> {
    const entry = this.store.get(key);
    if (!entry) return null;
    if (entry.expiresAt && Date.now() > entry.expiresAt) {
      this.store.delete(key);
      return null;
    }
    return entry.value;
  }

  async set(key: string, value: string): Promise<'OK'> {
    this.store.set(key, { value, expiresAt: null });
    return 'OK';
  }

  async setex(key: string, seconds: number, value: string): Promise<'OK'> {
    this.store.set(key, { value, expiresAt: Date.now() + seconds * 1000 });
    return 'OK';
  }

  async del(key: string): Promise<number> {
    return this.store.delete(key) ? 1 : 0;
  }

  async incr(key: string): Promise<number> {
    const existing = await this.get(key);
    const newVal = (parseInt(existing || '0', 10) + 1).toString();
    const entry = this.store.get(key);
    // Preserve existing TTL on increment
    this.store.set(key, { value: newVal, expiresAt: entry?.expiresAt ?? null });
    return parseInt(newVal, 10);
  }

  async setnx(key: string, value: string, expirySeconds?: number): Promise<boolean> {
    const existing = await this.get(key);
    if (existing !== null) return false;
    if (expirySeconds) {
      await this.setex(key, expirySeconds, value);
    } else {
      await this.set(key, value);
    }
    return true;
  }

  async ttl(key: string): Promise<number> {
    const entry = this.store.get(key);
    if (!entry) return -2;
    if (!entry.expiresAt) return -1;
    const remaining = Math.ceil((entry.expiresAt - Date.now()) / 1000);
    return remaining > 0 ? remaining : -2;
  }

  async ping(): Promise<string> {
    return 'PONG';
  }

  private evictExpired(): void {
    const now = Date.now();
    for (const [key, entry] of this.store) {
      if (entry.expiresAt && now > entry.expiresAt) {
        this.store.delete(key);
      }
    }
  }
}
