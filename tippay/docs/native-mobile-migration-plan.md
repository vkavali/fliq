# Native Mobile Migration Plan

## Goal

Move Fliq to:

- one shared backend
- one preserved web app, including the landing page and all current web flows
- one native iOS app with its own frontend codebase
- one native Android app with its own frontend codebase

Do not use Flutter as the long-term mobile frontend. Do not use webview or wrapper-based mobile apps. Do not break existing flows while migrating.

## Current State

### What exists today

- `apps/backend`: single NestJS backend
- `apps/web`: landing page plus active product flows
- `apps/mobile`: shared Flutter mobile frontend
- `apps/mobile/ios`: Flutter iOS runner project
- `apps/android`: native Android app with Gradle, `src/main`, manifest, main activity, auth/session flow, customer provider search, native QR scanner launch, QR and payment-link resolution, public provider detail, authenticated tip order creation, native Razorpay checkout handoff, backend callback verification, status polling, payment success and impact state, dev-bypass payment verification for mock orders, customer tip history, customer profile read/update, offline pending-tip persistence and retry, recurring-tip create/manage, tip-later create/pay/cancel, badges/streak/leaderboard views, native tip-jar resolve/pay, provider profile/tips/avatar upload/QR/payment-links/payouts/dream/invitation handling, provider bank-details save, Aadhaar eKYC initiate/verify/status, provider emoji responses, native tip-jar management, native tip-pool management, and business registration/dashboard/staff/invitations/satisfaction/QR group views plus CSV export preview and sharing
- `apps/ios`: native iOS app with XcodeGen, SwiftUI app shell, generated Xcode project, simulator build validation, auth/session flow, customer provider search, native AVFoundation QR scanner sheet, QR and payment-link resolution, public provider detail, authenticated tip order creation, native Razorpay checkout handoff, backend callback verification, status polling, payment success and impact state, dev-bypass payment verification for mock orders, customer tip history, customer profile read/update, offline pending-tip persistence and retry, recurring-tip create/manage, tip-later create/pay/cancel, badges/streak/leaderboard views, native tip-jar resolve/pay, provider profile/tips/avatar upload/QR/payment-links/payouts/dream/invitation handling, provider bank-details save, Aadhaar eKYC initiate/verify/status, provider emoji responses, native tip-jar management, native tip-pool management, and business registration/dashboard/staff/invitations/satisfaction/QR group views plus CSV export preview and sharing

### What does not exist yet

- no separate mobile design/API contract layer for iOS and Android

### Important implications

- The web app is not just marketing. It already contains login, tipping, provider, business, and tipper flows.
- Flutter is currently the main mobile frontend implementation.
- Android native now covers customer core, offline queue persistence, recurring tips, tip later, badges/streak/leaderboards, native tip jars, a substantial provider core slice including avatar upload, bank details, Aadhaar eKYC, business-affiliation visibility, tip-pool management, and provider analytics, plus a substantial business core slice including CSV export preview/sharing and deeper reporting cards. Push-token registration scaffolding is also in place. The remaining real gaps are live-device QA, Firebase credentials, and any last business/WhatsApp admin polish.
- iOS native now covers customer core, offline queue persistence, recurring tips, tip later, badges/streak/leaderboards, native tip jars, a substantial provider core slice including avatar upload, bank details, Aadhaar eKYC, business-affiliation visibility, tip-pool management, and provider analytics, plus a substantial business core slice including CSV export preview/sharing and deeper reporting cards. Push-token registration scaffolding is also in place. The remaining real gaps are live-device QA, APNs/Firebase credentials, and any last business/WhatsApp admin polish.

## Current Product Surface

### Public and anonymous flows

- Web landing page
- Direct tip page via provider ID or payment link
- QR resolution to provider info
- Anonymous tip creation and payment verification
- Public provider info
- Public dream display for a worker
- Public reputation display for a worker
- Public thank-you response lookup for a tip
- Public tip jar resolution and jar tipping

### Customer / tipper flows

- Phone OTP login
- Customer home
- QR scan
- Provider search
- Tip amount selection
- Payment success
- Tip history
- Profile
- Badges, streaks, leaderboard
- Recurring tips: create, list, pause, resume, cancel
- Tip later: promise, list, pay, cancel
- Tip jars: detail and tipping
- Tip pools: list, detail, create
- Offline pending tips queue

### Provider / worker flows

- Phone OTP login
- Provider onboarding
- Bank details
- KYC and Aadhaar eKYC
- QR generation and QR display
- Payment link creation and management
- Provider dashboard
- Earnings
- Payout request and payout history
- Settings and profile update
- Avatar upload
- Dream management
- Reputation visibility
- Worker responses to tips
- Recurring subscriber visibility
- Business affiliation and invitation response

### Business flows

- Email OTP login
- Business registration
- Dashboard and trend stats
- Staff breakdown
- Member invitation and removal
- Invitation acceptance and decline
- Satisfaction report
- Bulk QR code retrieval
- CSV export
- Web UI includes a WhatsApp tab, but backend configuration endpoints for that UI are not currently exposed in the same way as the other business flows

### Cross-cutting platform flows

- JWT refresh
- Push token registration and removal
- Webhook-driven payments
- Rate limiting
- Idempotency for sensitive payment flows

## Current Source of Truth

Use these files as the starting product contract during migration:

- `apps/web/public/index.html`
- `apps/web/public/app.js`
- `apps/mobile/lib/core/router/app_router.dart`
- `apps/backend/src/app.module.ts`
- backend controllers under `apps/backend/src/modules/*/*controller.ts`

## Target Architecture

## Repositories inside this monorepo

- `apps/backend`: keep as the single backend
- `apps/web`: keep as the current web app
- `apps/ios`: add new native iOS app
- `apps/android`: keep and complete as the new native Android app
- `apps/mobile`: keep temporarily as transition reference, then retire after parity is reached

## Native frontend stacks

### iOS

- Swift
- SwiftUI
- async/await networking
- APNs/FCM integration for notifications
- camera and QR support via native iOS frameworks

### Android

- Kotlin
- Jetpack Compose
- Coroutines and Flow
- Retrofit/OkHttp networking
- FCM integration
- CameraX or equivalent QR scanning stack

## What can be shared

- backend APIs
- OpenAPI schema or generated API contract
- design tokens
- copy/content
- iconography and image assets
- analytics event naming
- acceptance criteria

## What should not be shared

- UI layer
- view models
- navigation stacks
- platform state management
- platform-specific payment and notification wiring

## Migration Principles

- Web remains functional throughout migration.
- Backend contracts are stabilized before native feature work expands.
- Flutter stays as the reference app until iOS and Android reach parity.
- New product features should be avoided until parity-critical gaps are closed.
- Every migrated feature needs parity verification on web, iOS, and Android.

## Feature Parity Matrix

| Area | Web today | Flutter today | Native iOS target | Native Android target | Notes |
| --- | --- | --- | --- | --- | --- |
| Landing page | Yes | No | No | No | Preserve in `apps/web` exactly unless explicitly changed |
| Anonymous tip flow | Yes | Yes | Required | Required | Includes provider resolve, payment, verify, status |
| Phone OTP auth | Yes | Yes | Required | Required | Customer and provider login |
| Email OTP business auth | Yes | No explicit mobile route | Required | Required | Business login must exist on web and both native apps |
| Customer home/search/history/profile | Partial on web via tipper portal and demo | Yes | Required | Required | Native apps need full customer experience |
| QR scan | Demo and resolve paths on web | Yes | Required | Required | Native camera implementations |
| Provider onboarding | Yes | Yes | Required | Required | Includes bank details, KYC, QR, success |
| Aadhaar eKYC | Backend present | Yes | Required | Required | High-risk integration area |
| Provider dashboard | Yes | Yes | Required | Required | Earnings, payouts, QR, settings |
| Payment links | Yes | Yes | Required | Required | Shareable link management |
| Dreams | Yes | Not explicit in Flutter UI today | Required | Required | Current worker value proposition on web |
| Reputation | Yes | Partial mobile evidence | Required | Required | Public and provider-facing views |
| Worker responses | Yes | Partial mobile evidence | Required | Required | Thank-you loop |
| Recurring tips | Yes | Yes | Required | Required | Customer and provider views |
| Tip later | Web provider/tipper support | Yes | Required | Required | Promise lifecycle plus payment |
| Tip jars | Partial on web | Yes | Required | Required | Group tipping use case |
| Tip pools | Yes | Yes | Required | Required | Provider/business pooling flow |
| Gamification | Partial on web | Yes | Required | Required | Badges, streak, leaderboard |
| Offline queue | No meaningful web equivalent | Yes | Required | Required | Native offline handling must be designed per platform |
| Business dashboard | Yes | Partial | Required | Required | Business must remain on web and also ship on both native apps |
| Push notifications | Backend and Flutter support | Yes | Required | Required | Device token lifecycle and deep links |
| WhatsApp webhook/bot | Backend only | No | No native UI needed initially | No native UI needed initially | Treat as backend integration, not first-wave app UI |

## Locked Scope

Business is in scope for both native apps.

The migration target is:

- web keeps customer, provider, and business flows
- iOS ships customer, provider, and business flows
- Android ships customer, provider, and business flows

This increases parity cost and should be treated as a first-class requirement in all milestones.

## Recommended Implementation Plan

### Phase 0: Freeze and baseline

- Freeze backend contract changes except bug fixes.
- Capture current web and Flutter behaviors as reference videos and screenshots.
- Build a single parity checklist per role and per flow.
- Mark unclear or partially implemented areas, especially WhatsApp business UI and dreams/reputation coverage in Flutter.

### Phase 1: Contract and platform foundation

- Export and version the backend API contract.
- Add `apps/ios` native project.
- Complete `apps/android` native foundation with app source tree, manifest, main activity, signing setup, and app shell.
- Define shared design tokens and spacing/typography rules outside any UI framework.
- Define shared analytics and deeplink contracts.

### Phase 2: Customer core

- Splash and session restore
- Auth
- Home
- Search
- QR scan
- Tip amount
- Payment success
- History
- Profile

Status:

- implemented natively on both platforms: session restore, auth, customer home shell, provider search, native QR scan entry, QR and payment-link resolution by code or URL, public provider detail, tip amount/message/rating capture, authenticated tip order creation, native Razorpay checkout handoff, backend callback verification, backend tip-status polling, payment success and impact state, dev-bypass verification for mock Razorpay orders, customer tip history, customer profile read/update, recurring-tip create/manage, tip-later create/pay/cancel, and badges/streak/leaderboard views
- implemented natively on both platforms: offline pending-tip persistence, queued retry, and manual discard of pending drafts
- still pending on both platforms: full live device QA for camera and checkout flows

This phase unlocks the main tipper journey and should be the first production-ready milestone.

### Phase 3: Provider core

- Provider onboarding
- Bank details
- KYC and Aadhaar eKYC
- Dashboard
- Earnings
- QR display and generation
- Payment links
- Payouts
- Settings/profile

Status:

- implemented natively on both platforms: provider profile creation/update, provider home, tip history, QR list/create, payment-link list/create, payout history/request, active dream create/update, recurring supporter visibility, business invitation accept/decline, bank details save, Aadhaar eKYC initiate/verify/status, emoji thank-you responses, business-affiliation visibility, and richer provider analytics cards
- still pending on both platforms: live-device validation of push delivery and any deeper provider reporting polish that depends on backend expansion

### Phase 4: Business core

- Business email OTP login
- Business registration
- Business dashboard
- Staff management
- Invitations and responses
- Satisfaction report
- QR exports and bulk QR workflows
- Native-friendly export behavior where CSV download is not the right UX

Status:

- implemented natively on both platforms: business email OTP entry, business registration/update, dashboard snapshot, deeper reporting cards, staff list/removal, member invitation, satisfaction snapshot, QR-by-staff-group views, and CSV export preview plus native sharing
- still pending on both platforms: live-device validation for export/share behavior and any WhatsApp-specific management UI

### Phase 5: Retention and network features

- Dreams
- Reputation
- Worker responses
- Gamification
- Push notifications
- Offline queue

### Phase 6: Advanced financial and group flows

- Recurring tips
- Tip later
- Tip jars
- Tip pools

### Phase 7: Cutover

- Run side-by-side beta with native apps and Flutter reference app
- Fix parity gaps
- Retire Flutter app from active product path
- Keep web unchanged except for any intentional navigation or deeplink updates

## Definition of Done Per Feature

A feature is not complete on native until all of the following are true:

- backend API contract matches production behavior
- iOS implementation is complete
- Android implementation is complete
- web behavior remains unchanged unless intentionally updated
- analytics events are preserved or intentionally versioned
- deep links and notification routing work
- regression coverage exists for the backend and the affected clients

## Recommended Native App Boundaries

### Shared user-facing behavior

- same information architecture
- same data contract
- same pricing, payout, and payment logic
- same core UX patterns

### Allowed platform differences

- camera implementation
- notification permission flows
- secure storage implementation
- payment handoff details
- OS-specific sheet/navigation presentation

## Risks

### Highest risk

- feature parity drift while new work continues
- reimplementing payment flows differently across platforms
- incomplete understanding of web-only flows that users actively rely on
- rebuilding eKYC and notification flows without contract-level tests

### Current repo-specific risk

- push delivery still depends on external Firebase/APNs credentials and real-device validation
- some business WhatsApp UI appears ahead of backend management endpoints

## Immediate Next Steps

1. Run real-device QA for Android and iOS camera plus Razorpay checkout flows.
2. Drop in Firebase/APNs credentials and app identities so the new native push plumbing can actually register/send tokens.
3. Verify export/share, camera, and payment flows on physical Android and iPhone devices.
4. Decide whether WhatsApp-specific business UI needs a native surface or stays web-first.
5. Tighten backend reporting endpoints only if provider or business analytics need more depth than the current cards.

## Execution Backlog

### Epic 1: Shared contracts and migration guardrails

- Generate and version an API contract from the backend.
- Define auth, refresh token, deeplink, and analytics contracts.
- Freeze backend changes except parity-critical fixes.
- Record reference behavior for web and Flutter flows.
- Create parity test cases for customer, provider, and business roles.

### Epic 2: Android native foundation

- Complete `apps/android/app/src/main` structure.
- Add `AndroidManifest.xml`.
- Add `MainActivity.kt`.
- Add Compose app shell, theme, navigation, and dependency wiring.
- Add secure token storage, networking stack, and environment config.
- Add QR scanner, notification bootstrap, and payment integration foundation.
- Status: base shell now exists and compiles; next work is feature wiring.

### Epic 3: iOS native foundation

- Create `apps/ios` native project.
- Add SwiftUI app shell and navigation structure.
- Add networking layer, auth/session storage, and environment config.
- Add camera/QR foundation.
- Add notification registration and deep link routing.
- Add payment integration foundation.
- Status: base shell now exists and builds for simulator; next work is feature wiring.

### Epic 4: Customer parity

- Auth and session restore.
- Customer home and provider search.
- QR scan and provider resolution.
- Tip amount, rating, message, payment, and success flow.
- Tip history and profile.
- Offline queue behavior.
- Status: auth/session restore, provider search, native QR scanning, QR/payment-link resolve, provider public detail, tip order creation, native Razorpay checkout handoff, backend callback verification, backend status polling, payment success and impact state, dev-bypass mock verification, customer tip history, customer profile read/update, offline pending-tip persistence/retry, recurring-tip create/manage, tip-later create/pay/cancel, badges/streak/leaderboards, and native tip-jar resolve/pay are now live in both native apps. Remaining work is live device QA.

### Epic 5: Provider parity

- Provider onboarding and profile creation.
- Bank details and payout setup.
- KYC and Aadhaar eKYC.
- Dashboard, earnings, payouts, QR display, and QR generation.
- Payment links.
- Settings and avatar/profile editing.
- Status: provider home, profile creation/update, avatar upload, tips, QR, payment links, payouts, dream management, recurring supporter visibility, business invitation response, bank details, Aadhaar eKYC, emoji thank-you responses, business-affiliation visibility, provider analytics, and native tip-jar/tip-pool management are now live in both native apps. Remaining work is live-device QA and any analytics depth that requires backend expansion.

### Epic 6: Business parity

- Email OTP business login.
- Business registration.
- Dashboard and staff metrics.
- Invitations and invitation response handling.
- Staff management.
- Satisfaction reporting.
- Bulk QR and export workflows.
- Decide native replacement UX for raw CSV download where needed.
- Status: business email OTP entry, registration/update, dashboard snapshot, deeper reporting cards, staff management, invitations, satisfaction snapshot, QR group views, and CSV export preview plus native sharing are now live in both native apps. Remaining work is live-device QA for export/share behavior and any required WhatsApp-specific admin UI.

### Epic 7: Retention and advanced flows

- Dreams and reputation.
- Tip jars.
- Tip pools.
- Push notifications.
- Status: provider dream management, worker thank-you responses, gamification, recurring tips, tip later, tip jars, tip pools, and push-token registration/removal scaffolding are already live as part of the native customer/provider slices. Remaining work in this epic is credentials, notification delivery QA, and any deep-link routing polish after device tests.

### Epic 8: Cutover and retirement

- Beta rollout of native iOS and Android.
- Side-by-side parity verification against web and Flutter.
- Remove Flutter from active delivery path only after parity signoff.
- Keep web landing page and product flows unchanged unless explicitly planned.

## Recommendation

Do not add net-new product features until:

- native app scope is fixed
- parity checklist is approved
- Android and iOS foundations are in place
- backend contracts for the first migration wave are stabilized

Otherwise the migration will keep chasing a moving target and break the requirement of preserving every existing flow.
