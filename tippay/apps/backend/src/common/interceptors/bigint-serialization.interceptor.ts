import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable, map } from 'rxjs';

/**
 * Converts BigInt values to Number in all API responses.
 * JSON.stringify cannot handle BigInt natively, so this interceptor
 * recursively walks the response object and converts BigInt → Number.
 */
@Injectable()
export class BigIntSerializationInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(map((data) => this.serialize(data)));
  }

  private serialize(value: unknown): unknown {
    if (value === null || value === undefined) return value;
    if (typeof value === 'bigint') return Number(value);
    if (Array.isArray(value)) return value.map((item) => this.serialize(item));
    if (typeof value === 'object' && value instanceof Date) return value;
    if (typeof value === 'object') {
      const result: Record<string, unknown> = {};
      for (const [key, val] of Object.entries(value)) {
        result[key] = this.serialize(val);
      }
      return result;
    }
    return value;
  }
}
