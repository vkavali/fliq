import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    // Preserve raw body for webhook signature verification
    rawBody: true,
  });

  const configService = app.get(ConfigService);
  const port = configService.get<number>('APP_PORT', 3000);
  const env = configService.get<string>('APP_ENV', 'development');

  // Security
  app.use(helmet());
  app.enableCors({
    origin: env === 'development' ? '*' : configService.get<string>('APP_URL'),
  });

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
  app.useGlobalInterceptors(new LoggingInterceptor());

  // Swagger (development only)
  if (env === 'development') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('TipPay API')
      .setDescription('Indian UPI Tipping & Services Platform API')
      .setVersion('0.1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(port);
  console.log(`TipPay backend running on http://localhost:${port}`);
  if (env === 'development') {
    console.log(`Swagger docs at http://localhost:${port}/api/docs`);
  }
}

bootstrap();
