# Fliq — Indian UPI Tipping & Services Platform

A UPI-native tipping platform for India. Service providers (delivery, salon, restaurant staff) receive tips via QR code scanning. Customers scan, choose an amount, pay via Razorpay, and providers see earnings and request payouts.

## Architecture

```
tippay/
├── apps/
│   ├── backend/        NestJS API (TypeScript)
│   ├── mobile/         Flutter mobile app (Dart)
│   └── web/            Lightweight web client (vanilla JS)
├── packages/
│   ├── database/       Prisma schema + generated client (@fliq/database)
│   └── shared/         Shared types, constants, utils (@fliq/shared)
├── docker-compose.yml  PostgreSQL + Redis + Kafka (local dev)
└── railway.json        Railway deployment config
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | NestJS 10, TypeScript, Prisma 6 |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| Events | Kafka (transactional outbox pattern) |
| Payments | Razorpay (Orders, Webhooks, Route, RazorpayX, QR) |
| Mobile | Flutter 3.2+, Riverpod, Dio, GoRouter |
| Monorepo | pnpm workspaces + Turborepo |

## Prerequisites

- Node.js >= 20
- pnpm >= 9
- Docker & Docker Compose
- Flutter SDK >= 3.2 (for mobile development)

## Getting Started

### 1. Install dependencies

```bash
cd tippay
pnpm install
```

### 2. Start infrastructure

```bash
docker compose up -d
```

This starts PostgreSQL (port 5433), Redis (port 6379), and Kafka (port 9092).

### 3. Set up environment

```bash
cp .env.example .env
# Edit .env with your Razorpay keys if available
```

### 4. Build packages & run migrations

```bash
pnpm --filter @fliq/shared build
pnpm --filter @fliq/database build    # generates Prisma client
pnpm --filter @fliq/database migrate:dev
pnpm --filter @fliq/database seed     # seed test data
```

### 5. Start the backend

```bash
pnpm --filter @fliq/backend dev
```

The API will be available at `http://localhost:3000`. Swagger docs at `http://localhost:3000/api`.

### 6. Start the web client (optional)

```bash
cd apps/web && npx serve public -l 5173
```

### 7. Run Flutter app (optional)

```bash
cd apps/mobile
flutter pub get
flutter run
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/otp/send` | No | Send OTP to phone |
| POST | `/auth/otp/verify` | No | Verify OTP, get JWT |
| POST | `/auth/refresh` | No | Refresh access token |
| GET | `/users/me` | JWT | Get current user |
| PATCH | `/users/me` | JWT | Update profile |
| POST | `/providers/profile` | JWT | Create provider profile |
| GET | `/providers/:id/public` | No | Public provider info |
| POST | `/tips` | No | Create tip + Razorpay order |
| POST | `/tips/:id/verify` | No | Verify payment signature |
| GET | `/tips/provider` | JWT | Provider's received tips |
| GET | `/tips/customer` | JWT | Customer's given tips |
| POST | `/payouts/request` | JWT | Request payout |
| GET | `/payouts/history` | JWT | Payout history |
| POST | `/qrcodes` | JWT | Generate QR code |
| GET | `/qrcodes/:id/resolve` | No | Resolve QR for scanner |
| POST | `/webhooks/razorpay` | HMAC | Razorpay webhook handler |
| GET | `/admin/stats` | Admin | Platform statistics |
| POST | `/admin/payouts/batch` | Admin | Trigger batch payouts |

## Testing

```bash
# Backend unit tests
cd apps/backend && npx jest

# Type checking
cd apps/backend && npx tsc --noEmit
```

## Commission Model

- Tips <= Rs 100: **0% commission** (builds trust)
- Tips > Rs 100: **5% commission**
- 18% GST on commission amount
- All amounts stored as BigInt (paise) to avoid floating-point errors

## Key Design Decisions

- **Double-entry ledger** with optimistic locking for wallet operations
- **Transactional outbox** pattern for reliable Kafka event publishing
- **Webhook idempotency** via unique `eventId` constraint
- **Redis-backed rate limiting** and idempotency for all sensitive endpoints
- **Raw body preservation** for Razorpay HMAC signature verification
- **BigInt serialization** interceptor for JSON responses

## Deployment

The project includes a Dockerfile and `railway.json` for Railway deployment. Required environment variables are listed in `.env.example`.

```bash
# Build production Docker image
docker build -f apps/backend/Dockerfile -t fliq-backend .
```

## License

Private — All rights reserved.
