# Fliq — Indian UPI Tipping & Services Platform

## Project Overview
A UPI-native tipping platform for India. Service providers (delivery, salon, restaurant staff) receive tips via QR code scanning. Customers scan, choose amount, pay via Razorpay. Providers see earnings and request payouts.

## Monorepo Structure
- `apps/backend/` — NestJS (TypeScript) API server
- `apps/mobile/` — Flutter (Dart) mobile app
- `packages/database/` — Prisma schema + generated client (`@fliq/database`)
- `packages/shared/` — Shared types, constants, utils (`@fliq/shared`)

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
pnpm --filter @fliq/shared build
pnpm --filter @fliq/database build

# Start backend dev server
pnpm --filter @fliq/backend dev

# Type-check backend
cd apps/backend && npx tsc --noEmit

# Run backend tests
cd apps/backend && npx jest

# Start Docker services (PostgreSQL, Redis, Kafka)
docker compose up -d

# Run Prisma migrations
pnpm --filter @fliq/database migrate:dev

# Generate Prisma client
pnpm --filter @fliq/database build

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

## Deployment & Infrastructure
- Railway deployment from `master` branch via `apps/backend/Dockerfile`
- PostgreSQL (Railway managed), Redis (Railway managed)
- Web frontend served as static files from `apps/web/public/` via NestJS `useStaticAssets` at `/app/`
- Domain: `fliq.co.in`
- Dedicated tip page: `tip.html` (separate from SPA, uses payment-links API)

## Web Frontend (SPA)
- `apps/web/public/` — vanilla JS single-page app (no framework)
- Pages: `#landing-page`, `#login-page`, `#dashboard-page`, `#tip-page`
- Navigation: `goTo(page)` function toggles page divs
- CSS classes: landing page uses `lp-` prefix; existing brand/tip/dashboard classes untouched
- Logo: `logo-full.png` (purple Fl₹q with gold rupee as 'i')

## Environment Variables (Critical)
- `APP_ENV` — controls dev/prod behavior (OTP logging, Swagger visibility, CORS). Must be `production` in Railway.
- `NODE_ENV` — set in Dockerfile. Some services historically checked this instead of `APP_ENV` (now fixed).
- `JWT_SECRET` — must be strong random value in production (min 16 chars), not the hardcoded dev default.
- `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` — live keys required for production payments.
- `RAZORPAY_WEBHOOK_SECRET` — required for webhook signature verification.
- `MSG91_AUTH_KEY` — required for production SMS delivery.
- Env validation via Joi schema in `src/config/env.validation.ts` — app fails fast if critical vars missing.

## API Endpoints (key ones)
- `GET /providers/:id/public` — provider lookup by UUID only
- `GET /payment-links/:code/resolve` — resolves short code OR UUID (preferred for tip flow)
- `POST /auth/otp/send` — sends OTP, rate-limited
- `POST /auth/otp/verify` — verifies OTP, returns JWT
- `POST /tips` — create tip + Razorpay order
- `POST /tips/:id/verify` — verify payment after Razorpay checkout
- `GET /api/docs` — Swagger (dev-only, hidden in production)

## Branch Strategy
- `master` — production deployments (Railway auto-deploys)
- `dev` — development branch (merge to master for deploy)
