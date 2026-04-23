# Fliq — Project Context & Status

> This file is committed to git so any machine/session can pick up where we left off.
> Last updated: 2026-03-23 (Session 2 — major feature build)

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

## Mobile App Status: PWA / CAPACITOR (v0.5)

### Existing Screens (PWA/Web)
| Screen | Path | Status |
|--------|------|--------|
| Login (phone entry) | /login | Works |
| OTP verification | /otp | Works |
| Business Login | /business-login | Works |
| Tipper Portal | /tipper-portal | Works |
| Customer Home | /home | PWA layout |
| Tip Amount | /tip | Works — presets, rating, message, Razorpay checkout |
| Provider Dashboard | /dashboard | Works — stats, tip links, payouts |
| Provider QR Display | /my-qr | Works — shows QR codes |

### Mobile Architecture Shift
- We transitioned from native Flutter to a PWA wrapped with **Capacitor** (`apps/android` and `apps/ios`).
- Flutter (`apps/mobile`) directory has been removed/deprecated.
- The web app dynamically detects native and PWA contexts (in `app.js`) to serve an app-like experience.

### What's Missing in Mobile (Capacitor)
**Critical:**
- Build and test Android APK / iOS IPA using Capacitor CLI
- Push/in-app notifications via Firebase Cloud Messaging plugin
- App store prep — icon, splash, screenshots, store listing

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

## Changelog

### Session 2 — 2026-03-23 (Major Feature Build)

**Mobile App Overhaul (v0.1 → v0.8):**
- Rewrote ALL customer screens (home, scan, tip, success, history) with modern UI
- Rewrote ALL provider screens (dashboard, earnings, payouts, QR display)
- Added splash screen with auth persistence
- Added bottom navigation (customer: Home/Scan/History/Profile; provider: Dashboard/QR/Earnings/Payouts/Settings)
- Added settings screen (language, payout pref, UPI VPA, logout)
- Added customer profile screen
- Created proper models for all backend entities (User, Provider, Tip, Payout, QrCode, PaymentLink, TipPool, Badge, Streak)
- Created auth service with token persistence + auto-refresh

**New Feature: WhatsApp Tip Links** (backend + mobile + web)
- Backend: PaymentLinks module (POST/GET/DELETE /payment-links, GET resolve by shortCode)
- Prisma: PaymentLink model with shortCode
- Web: tip.html — beautiful mobile-first landing page for WhatsApp shared links
- Mobile: "Share via WhatsApp" button on provider dashboard
- Backend: GET /tip/:shortCode route serves the landing page

**New Feature: UPI Intent Flow** (mobile)
- Direct UPI app launching (GPay, PhonePe, Paytm) from tip screen
- Constructs upi://pay intent URL with provider VPA
- Falls back to Razorpay checkout if no UPI app available

**New Feature: Provider Discovery** (backend + mobile)
- Backend: GET /providers/search with name/phone query + category filter
- Mobile: ProviderSearchScreen with debounced search, category chips, results list
- Home screen categories are now tappable → navigate to search with filter

**New Feature: Multi-Language (i18n)** (mobile)
- 6 languages: English, Hindi, Tamil, Telugu, Kannada, Marathi
- 66 string keys with real translations (not Google Translate)
- Map-based AppStrings system with locale provider (Riverpod)
- Settings screen language selector updates UI + syncs to backend

**New Feature: Tip Pools** (backend + mobile)
- Backend: TipPools module with CRUD, member management, earnings distribution
- Prisma: TipPool + TipPoolMember models
- Split methods: EQUAL, PERCENTAGE, ROLE_BASED
- Auto-detection: tips to pool members auto-link to pool
- Mobile: TipPoolsScreen, PoolDetailScreen, CreatePoolScreen
- Distribution logic credits each member's wallet

**New Feature: Gamification** (backend + mobile)
- Backend: Gamification module with badges, streaks, leaderboards
- Prisma: Badge, UserBadge, TipStreak models
- 13 badges seeded on startup (tipper, provider, streak categories)
- Streak tracking (daily consecutive tipping)
- Leaderboards (week/month, tippers/providers)
- Hooked into payment settlement (auto-awards after each tip)
- Mobile: BadgesScreen, LeaderboardScreen, StreakScreen
- Streak banner + badges section on home/dashboard screens

**Errors Encountered & Fixed:**
- CardTheme → CardThemeData (Flutter 3.41 API change)
- iOS deployment target 9.0 → 14.0 (Xcode 26 requirement)
- Missing iOS platform folder → flutter create --platforms ios
- Missing asset directories → mkdir
- withOpacity deprecated → withValues(alpha:)
- Git HTTPS auth → SSH

### Session 1 — 2026-03-23 (Initial Setup)
- Installed Flutter, CocoaPods, Xcode setup
- Generated iOS platform, fixed build errors
- Successfully ran app on iPhone wirelessly
- Created CONTEXT.md for cross-machine continuity

---

## Remaining Work (Priority Order)
1. **Provider onboarding flow** — KYC, bank details, PAN verification screens
2. **Push notifications** — FCM integration, real-time tip alerts
3. **Admin dashboard** — mobile or web admin panel
4. **Prisma migration** — run `prisma migrate dev` for new tables (PaymentLink, TipPool, TipPoolMember, Badge, UserBadge, TipStreak)
5. **Deploy backend** — push new modules to Railway
6. **Install Node.js locally** — needed for backend dev/testing on this machine
7. **Integration testing** — end-to-end tip flow on phone
8. **App polish** — Lottie animations, skeleton loaders, haptic feedback
9. **App store prep** — icon, splash, screenshots, store listing
