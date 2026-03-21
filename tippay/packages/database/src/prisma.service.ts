import { PrismaClient } from '@prisma/client';

/**
 * NestJS-compatible Prisma service.
 * Extends PrismaClient and manages connection lifecycle.
 *
 * Usage in NestJS module:
 *   providers: [PrismaService]
 *   exports: [PrismaService]
 *
 * Then call onModuleInit() and onModuleDestroy() via NestJS lifecycle hooks.
 */
export class PrismaService extends PrismaClient {
  constructor() {
    super({
      log:
        process.env.APP_ENV === 'development'
          ? ['query', 'warn', 'error']
          : ['warn', 'error'],
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
