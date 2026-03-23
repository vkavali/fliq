# Fliq — Project Context & Status

> This file is committed to git so any machine/session can pick up where we left off.
> Last updated: 2026-03-23

---

## What Is Fliq?
A UPI-native tipping platform for India. Service providers (delivery, salon, restaurant, hotel staff) receive tips via QR code scanning. Customers scan, choose amount, pay via Razorpay. Providers see earnings and request payouts.

## Competitor: TipPay (tippay.co.in)
- Global product (cards, Apple Pay, Samsung Pay) — **not UPI-native** in India
- Has ratings & reviews, analytics dashboard, multi-QR per worker
- B2B2C model (sells through banks) — slower adoption
- Opaque pricing, no public fee schedule
- Thin web presence, English-only
- No WhatsApp integration, no tip pooling, no POS integration

## Our Advantages Over TipPay
1. **UPI-native** via Razorpay — the dominant payment method in India
2. **Transparent pricing** — 0% commission on tips <= Rs 100, 5% above
3. **Production-grade backend** — double-entry ledger, optimistic locking, transactional outbox
4. **Multi-language support** — 6 Indian languages (en, hi, ta, te, kn, mr)
5. **Instant payouts** — RazorpayX same-day payouts

## Differentiation Opportunities (Not Yet Built)
1. WhatsApp tip links (share via WhatsApp, not just QR)
2. UPI intent flow (tap to open GPay/PhonePe directly)
3. Tip pools for restaurant teams
4. Provider discovery (search/browse without QR)
5. Micro-tip gamification (streaks, badges, leaderboards)
6. Vernacular language UI (Hindi, Telugu, Tamil, etc.)
7. POS integration (Petpooja, Posist)

---

## Monorepo Structure
```
tippay/
├── apps/
│   ├── backend/        NestJS API (TypeScript) — FEATURE-COMPLETE
│   ├── mobile/         Flutter mobile app (Dart) — NEEDS WORK
│   └── web/            Vanilla JS web client — BASIC BUT FUNCTIONAL
├── packages/
│   ├── database/       Prisma schema + generated client (@fliq/database)
│   └── shared/         Shared types, constants, utils (@fliq/shared)
├── docker-compose.yml  PostgreSQL + Redis + Kafka (local dev)
└── railway.json        Railway deployment config
```

## Tech Stack
- **Backend**: NestJS 10, Prisma 6, PostgreSQL 16, Redis 7, Kafka
- **Mobile**: Flutter 3.41+, Riverpod, Dio, GoRouter, razorpay_flutter
- **Web**: Vanilla JS SPA
- **Payments**: Razorpay (Orders, Webhooks, Route splits, RazorpayX payouts, QR codes)
- **Deployment**: Railway (backend), Docker

---

## Backend Status: FEATURE-COMPLETE (v1.0)

### Modules & Endpoints
| Module | Endpoints | Status |
|--------|-----------|--------|
| Auth | POST /auth/otp/send, /otp/verify, /refresh | Done |
| Users | GET /users/me, PATCH /users/me | Done |
| Providers | POST/GET/PATCH /providers/profile, GET /providers/:id/public | Done |
| Tips | POST /tips, POST /tips/authenticated, POST /tips/:id/verify, GET /tips/provider, GET /tips/customer | Done |
| QR Codes | POST /qrcodes, GET /qrcodes/my, GET /qrcodes/:id/resolve | Done |
| Payments | Razorpay orders, verification, transfers | Done |
| Webhooks | POST /webhooks/razorpay (payment.captured, payment.failed, payout.processed, payout.failed) | Done |
| Wallets | Double-entry ledger, optimistic locking, PROVIDER_EARNINGS + PLATFORM_COMMISSION + TAX_RESERVE | Done |
| Payouts | POST /payouts/request, GET /payouts/history (UPI/IMPS/NEFT modes) | Done |
| Admin | GET /admin/stats, /admin/tips, /admin/providers, /admin/payouts, /admin/wallets, POST /admin/payouts/batch | Done |
| Notifications | SMS service (dev: console, prod: MSG91 stub) | Done |
| Outbox | Transactional outbox poller + Kafka producer/consumer | Done |

### Key Architecture
- All amounts in **paise (BigInt)** — never floating-point
- UUID v4 for all IDs
- Double-entry ledger with LedgerEntry for every wallet operation
- Optimistic locking (Wallet.version) prevents double-spend
- Transactional outbox guarantees Kafka delivery
- Webhook idempotency via eventId unique constraint
- Raw body for HMAC signature verification
- Redis-backed rate limiting + idempotency (24h TTL)

### Commission Model
- Tips <= Rs 100 (10,000 paise): **0% commission**
- Tips > Rs 100: **5% commission**
- 18% GST on commission
- 1% TDS on earnings > Rs 5L/FY (Section 194O)

---

## Mobile App Status: NEEDS MAJOR WORK (v0.1)

### Existing Screens
| Screen | Path | Status |
|--------|------|--------|
| Login (phone entry) | /login | Works |
| OTP verification | /otp | Works |
| Customer Home | /home | Basic — scan button + quick actions |
| QR Scanner | /scan | Works (mobile_scanner) |
| Tip Amount | /tip | Works — presets, rating, message, Razorpay checkout |
| Payment Success | /payment-success | Basic confirmation |
| Transaction History | /history | Basic list |
| Provider Dashboard | /dashboard | Basic — tips count, recent tips, quick actions |
| Provider QR Display | /my-qr | Works — shows QR codes |
| Provider Earnings | /earnings | Basic list |
| Provider Payouts | /payouts | Basic — request + history |

### What's Missing in Mobile (65+ features)
**Critical:**
- Provider onboarding (KYC, bank details, PAN, fund account)
- Commission/fee transparency in UI
- Wallet balance display
- Multi-language selector
- Settings screen
- Auth persistence (splash → restore session)
- Push/in-app notifications

**Important:**
- Admin dashboard
- Tax reporting (TDS/TCS/GST breakdown)
- Advanced analytics (charts, trends)
- QR code analytics (scan counts)
- Payment method display
- Payout mode selection (UPI/IMPS/NEFT)
- Data export

**Nice-to-have:**
- Provider search/discovery
- Favorites/bookmarks
- Profile pictures
- Offline mode
- Referral system

### UI Quality
- **Good foundation**: Material 3 theme, Google Fonts (Inter), consistent spacing, color palette
- **Missing polish**: No animations (Lottie unused), no skeleton loaders (shimmer unused), no custom loading states, no empty state illustrations, basic snackbar errors only, no bottom navigation bar, no swipe-to-refresh, no infinite scroll pagination

---

## Web App Status: FUNCTIONAL (v0.5)
- Provider login + dashboard
- Customer tip page (QR landing → amount → Razorpay checkout)
- Commission breakdown display
- QR code grid with location labels
- Payout request + history
- Receipt/success screen

---

## Deployment
- **Backend**: Railway (https://fliq-production-9ac7.up.railway.app)
- **Database**: Railway PostgreSQL
- **Redis**: Railway Redis
- **API Base URL**: https://fliq-production-9ac7.up.railway.app

---

## Development Setup
```bash
# Install dependencies
cd tippay && pnpm install

# Build packages
pnpm --filter @fliq/shared build
pnpm --filter @fliq/database build

# Start Docker services (local dev)
docker compose up -d

# Start backend
pnpm --filter @fliq/backend dev

# Start Flutter app
cd apps/mobile && flutter pub get && flutter run

# Start web client
cd apps/web && npx serve public -l 5173
```

---

## Next Steps (Priority Order)
1. **Add full customer flow to mobile app** — scan QR, see provider, pick amount, pay, success
2. **Polish UI** — animations, skeleton loaders, bottom nav, proper empty states
3. **Provider onboarding flow** — KYC, bank details, PAN verification
4. **Expose existing backend features** — wallet balance, commission breakdown, analytics, multi-language
5. **WhatsApp tip links** — share tipping link via WhatsApp
6. **Push notifications** — real-time tip alerts
7. **Admin mobile/web dashboard**
