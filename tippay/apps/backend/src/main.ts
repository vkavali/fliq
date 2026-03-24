import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { join } from 'path';
import { existsSync } from 'fs';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { BigIntSerializationInterceptor } from './common/interceptors/bigint-serialization.interceptor';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    // Preserve raw body for webhook signature verification
    rawBody: true,
  });

  const configService = app.get(ConfigService);
  const port = configService.get<number>('PORT') || configService.get<number>('APP_PORT', 3000);
  const env = configService.get<string>('APP_ENV', 'development');

  app.use(helmet({
    contentSecurityPolicy: env === 'production'
      ? {
          directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
            fontSrc: ["'self'", "https://fonts.gstatic.com"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'"],
          },
        }
      : false,
    crossOriginEmbedderPolicy: false,
  }));

  const allowedOrigins = env === 'production'
    ? ['https://fliq.co.in', 'https://www.fliq.co.in']
    : ['http://localhost:3000', 'http://localhost:5173'];
  app.enableCors({ origin: allowedOrigins, credentials: true });

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

  // Swagger — only in development
  if (env !== 'production') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Fliq API')
      .setDescription('Indian UPI Tipping & Services Platform API')
      .setVersion('0.1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(port);
  console.log(`Fliq backend running on http://localhost:${port}`);
  if (env !== 'production') {
    console.log(`Swagger docs at http://localhost:${port}/api/docs`);
  }
}

bootstrap();
