# TipPay — Indian UPI Tipping & Services Platform

## Project Overview
A UPI-native tipping platform for India. Service providers (delivery, salon, restaurant staff) receive tips via QR code scanning. Customers scan, choose amount, pay via Razorpay. Providers see earnings and request payouts.

## Monorepo Structure
- `apps/backend/` — NestJS (TypeScript) API server
- `apps/mobile/` — Flutter (Dart) mobile app
- `packages/database/` — Prisma schema + generated client (`@tippay/database`)
- `packages/shared/` — Shared types, constants, utils (`@tippay/shared`)

## Tech Stack
- **Backend**: NestJS 10, Prisma 6, PostgreSQL 16, Redis 7, Kafka
- **Mobile**: Flutter 3.2+, Riverpod, Dio, go_router, razorpay_flutter
- **Payments**: Razorpay (Orders, Webhooks, Route splits, RazorpayX payouts, QR codes)
- **Monorepo**: pnpm workspaces + Turborepo

## Backend Modules
| Module | Path | Description |
|--------|------|-------------|
| Auth | `modules/auth/` | Phone OTP + JWT (rate-limited, redis-backed) |
| Users | `modules/users/` | User profile CRUD |
| Providers | `modules/providers/` | Provider onboarding, KYC, wallet creation |
| Tips | `modules/tips/` | Create tip + Razorpay order, verify payment |
| Payments | `modules/payments/` | Razorpay SDK, webhooks, settlement |
| Wallets | `modules/wallets/` | Double-entry ledger, optimistic locking |
| Payouts | `modules/payouts/` | RazorpayX payout requests |
| QR Codes | `modules/qrcodes/` | Razorpay QR generation, resolve for scanner |
| Notifications | `modules/notifications/` | SMS (dev: console, prod: MSG91) |
| Admin | `modules/admin/` | Platform stats, tips/providers/payouts lists, batch payouts |
| Outbox | `modules/outbox/` | Transactional outbox poller + Kafka producer/consumer |

## Key Commands
```bash
# Install dependencies
pnpm install

# Build packages (required before backend)
pnpm --filter @tippay/shared build
pnpm --filter @tippay/database build

# Start backend dev server
pnpm --filter @tippay/backend dev

# Type-check backend
cd apps/backend && npx tsc --noEmit

# Run backend tests
cd apps/backend && npx jest

# Start Docker services (PostgreSQL, Redis, Kafka)
docker compose up -d

# Run Prisma migrations
pnpm --filter @tippay/database migrate:dev

# Generate Prisma client
pnpm --filter @tippay/database build

# Deploy (Railway)
# Uses apps/backend/Dockerfile and railway.json
```

## Architecture Rules
1. **All amounts in paise** (BigInt) — never floating-point for money
2. **UUID v4 for all IDs** — no enumeration attacks
3. **Double-entry ledger** — every wallet credit/debit has a LedgerEntry
4. **Optimistic locking** — Wallet.version column prevents double-spend
5. **Transactional outbox** — OutboxEvent table guarantees Kafka delivery
6. **Webhook idempotency** — WebhookEvent.eventId unique constraint
7. **Raw body for webhooks** — NestJS rawBody:true for HMAC signature verification
8. **BigInt serialization** — global interceptor converts BigInt → Number in responses
9. **Idempotency** — Redis-backed interceptor with `Idempotency-Key` header (24h TTL)
10. **Rate limiting** — Redis-backed guard with `@RateLimit()` decorator

## Commission Model
- Tips <= Rs 100 (10,000 paise): **0% commission**
- Tips > Rs 100: **5% commission**
- 18% GST on commission amount

## Code Standards
- No hallucinated APIs — only use what exists in the codebase
- Read before writing — always understand existing code first
- Smallest safe change — don't over-engineer
- Always verify — type-check after changes
- DTOs use `!:` for class-validator populated properties
- Backend doesn't emit declarations (app, not library)
- Tests use mocked Prisma and services — no DB required
