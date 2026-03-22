import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { join } from 'path';
import { existsSync } from 'fs';
import { execSync } from 'child_process';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { BigIntSerializationInterceptor } from './common/interceptors/bigint-serialization.interceptor';

// Run prisma db push before app starts to ensure tables exist
try {
  console.log('=== Running prisma db push ===');
  const schemaPath = join(__dirname, '..', '..', '..', 'packages', 'database', 'prisma', 'schema.prisma');
  execSync(`npx prisma db push --schema=${schemaPath} --skip-generate --accept-data-loss`, {
    stdio: 'inherit',
    timeout: 30000,
  });
  console.log('=== DB push complete ===');
} catch (e) {
  console.error('=== DB push failed ===', (e as Error).message);
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    // Preserve raw body for webhook signature verification
    rawBody: true,
  });

  const configService = app.get(ConfigService);
  const port = configService.get<number>('PORT') || configService.get<number>('APP_PORT', 3000);
  const env = configService.get<string>('APP_ENV', 'development');

  app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
  }));
  app.enableCors({
    origin: '*',
  });

  // Serve web app static files from /app (if present)
  const webAppPath = join(__dirname, '..', '..', 'web', 'public');
  if (existsSync(webAppPath)) {
    app.useStaticAssets(webAppPath, { prefix: '/app/' });
  }

  // Global pipes
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Global filters and interceptors
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(
    new LoggingInterceptor(),
    new BigIntSerializationInterceptor(),
  );

  // Swagger
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Fliq API')
    .setDescription('Indian UPI Tipping & Services Platform API')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(port);
  console.log(`Fliq backend running on http://localhost:${port}`);
  if (env === 'development') {
    console.log(`Swagger docs at http://localhost:${port}/api/docs`);
  }
}

bootstrap();
