import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '@fliq/database';
import { BigIntSerializationInterceptor } from '../src/common/interceptors/bigint-serialization.interceptor';

/**
 * End-to-end test for the full tip lifecycle.
 *
 * Requirements: PostgreSQL + Redis running (via Docker Compose)
 * Run: npx jest --config test/jest-e2e.json
 *
 * This test covers:
 * 1. Health check
 * 2. Send OTP
 * 3. Verify OTP → get JWT
 * 4. Create provider profile
 * 5. Create a tip (unauthenticated QR flow)
 * 6. Verify tip payment (mocked signature — will fail in real env)
 * 7. Get customer tip history
 * 8. Get provider tip history
 */
describe('Tip Flow (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let userId: string;
  let providerId: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    app.useGlobalInterceptors(new BigIntSerializationInterceptor());

    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health — should return ok', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect((res) => {
        expect(res.body.status).toBe('ok');
        expect(res.body.service).toBe('fliq-backend');
      });
  });

  it('POST /auth/otp/send — should send OTP', () => {
    return request(app.getHttpServer())
      .post('/auth/otp/send')
      .send({ phone: '+919999900001' })
      .expect(200)
      .expect((res) => {
        expect(res.body.message).toBe('OTP sent successfully');
      });
  });

  it('POST /auth/otp/verify — should return tokens', async () => {
    // Fetch the OTP from the database (dev mode stores it)
    const otpRecord = await prisma.otpCode.findFirst({
      where: { phone: '+919999900001', verified: false },
      orderBy: { createdAt: 'desc' },
    });

    expect(otpRecord).toBeTruthy();

    const res = await request(app.getHttpServer())
      .post('/auth/otp/verify')
      .send({ phone: '+919999900001', code: otpRecord!.code })
      .expect(200);

    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(res.body.user.phone).toBe('+919999900001');

    accessToken = res.body.accessToken;
    userId = res.body.user.id;
  });

  it('POST /auth/refresh — should return new access token', async () => {
    // First get a refresh token
    const otpRecord = await prisma.otpCode.findFirst({
      where: { phone: '+919999900001', verified: true },
      orderBy: { createdAt: 'desc' },
    });

    // Send another OTP and verify to get a fresh refresh token
    await request(app.getHttpServer())
      .post('/auth/otp/send')
      .send({ phone: '+919999900002' })
      .expect(200);

    const otp2 = await prisma.otpCode.findFirst({
      where: { phone: '+919999900002', verified: false },
      orderBy: { createdAt: 'desc' },
    });

    const loginRes = await request(app.getHttpServer())
      .post('/auth/otp/verify')
      .send({ phone: '+919999900002', code: otp2!.code })
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({ refreshToken: loginRes.body.refreshToken })
      .expect(200);

    expect(res.body.accessToken).toBeDefined();
  });

  it('GET /users/me — should return current user', () => {
    return request(app.getHttpServer())
      .get('/users/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.id).toBe(userId);
        expect(res.body.phone).toBe('+919999900001');
      });
  });

  it('POST /providers/profile — should create provider profile', async () => {
    const res = await request(app.getHttpServer())
      .post('/providers/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ category: 'RESTAURANT' })
      .expect(201);

    providerId = res.body.id;
    expect(providerId).toBe(userId);
  });

  it('GET /providers/:id/public — should return public profile', () => {
    return request(app.getHttpServer())
      .get(`/providers/${providerId}/public`)
      .expect(200)
      .expect((res) => {
        expect(res.body.id).toBe(providerId);
        expect(res.body.category).toBe('RESTAURANT');
      });
  });

  it('POST /tips — should create a tip (unauthenticated)', async () => {
    const res = await request(app.getHttpServer())
      .post('/tips')
      .send({
        providerId,
        amountPaise: 5000,
        source: 'QR_CODE',
        message: 'Great food!',
        rating: 5,
      })
      .expect(201);

    expect(res.body.tipId).toBeDefined();
    expect(res.body.orderId).toBeDefined();
    expect(res.body.amount).toBe(5000);
    expect(res.body.currency).toBe('INR');
  });

  it('POST /tips — should reject invalid provider', () => {
    return request(app.getHttpServer())
      .post('/tips')
      .send({
        providerId: '00000000-0000-0000-0000-000000000000',
        amountPaise: 5000,
        source: 'QR_CODE',
      })
      .expect(400);
  });

  it('POST /tips — should reject amount below minimum', () => {
    return request(app.getHttpServer())
      .post('/tips')
      .send({
        providerId,
        amountPaise: 100, // Below 1000 minimum
        source: 'QR_CODE',
      })
      .expect(400);
  });

  it('GET /tips/provider — should list provider tips', () => {
    return request(app.getHttpServer())
      .get('/tips/provider')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.tips).toBeDefined();
        expect(Array.isArray(res.body.tips)).toBe(true);
        expect(res.body.total).toBeGreaterThanOrEqual(0);
      });
  });

  it('GET /tips/customer — should list customer tips', () => {
    return request(app.getHttpServer())
      .get('/tips/customer')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.tips).toBeDefined();
        expect(Array.isArray(res.body.tips)).toBe(true);
      });
  });

  it('GET /tips/customer — should reject without auth', () => {
    return request(app.getHttpServer())
      .get('/tips/customer')
      .expect(401);
  });
});
