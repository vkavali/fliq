# Fliq — End-to-End Testing Guide

## Overview

A master test account system lets you test every Fliq feature **without any external service dependencies** (no Razorpay keys, no MSG91 SMS, no WhatsApp API tokens needed).

Controlled by a single env var: `DEV_BYPASS_ENABLED=true`

---

## Test Accounts

| Role | Phone | OTP | JWT Type |
|------|-------|-----|----------|
| **Test Tipper** | `+919999999999` | `123456` | ADMIN (access to all endpoints) |
| **Test Worker** | `+919999999998` | `123456` | PROVIDER |

Both accounts accept OTP `123456` when `DEV_BYPASS_ENABLED=true`.
Payments use mock Razorpay orders — full lifecycle (INITIATED → PAID → wallet credited) works without real Razorpay keys.

---

## Setup

### 1. Enable bypass in Railway

In Railway → your backend service → Variables:
```
DEV_BYPASS_ENABLED=true
```

### 2. Seed test data

After deploying, call the seed endpoint once:
```bash
curl -X POST https://fliq.co.in/dev/seed
```

This creates:
- Test Tipper (ADMIN) + Test Worker (PROVIDER)
- ₹10,000 pre-funded wallet for each
- Payment link: `testwrkr`
- QR code for Test Worker
- Test Cafe business with Test Worker as staff
- 3 sample paid tips (history)
- Test tip jar (`test-jar`)
- Test tip pool (`Test Cafe Tip Pool`)

Check status anytime:
```bash
curl https://fliq.co.in/dev/status
```

---

## Feature Test Flows

### A. Login (Auth)

**Test Tipper login:**
```bash
# Step 1: Send OTP (returns immediately, no SMS sent)
curl -X POST https://fliq.co.in/auth/otp/send \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919999999999"}'
# Response: {"message":"OTP sent (dev bypass active — use 123456)"}

# Step 2: Verify OTP → get JWT
curl -X POST https://fliq.co.in/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919999999999", "code": "123456"}'
# Response: {"accessToken":"eyJ...", "refreshToken":"eyJ...", "user":{...}}
```

Save the `accessToken` as `TIPPER_TOKEN` and repeat for `+919999999998` to get `WORKER_TOKEN`.

---

### B. User Profile

```bash
curl https://fliq.co.in/users/me \
  -H "Authorization: Bearer $TIPPER_TOKEN"
```

---

### C. Tipping Flow (Core Feature)

**Via the web UI:**
1. Open `https://fliq.co.in/app/tip.html?code=testwrkr`
2. Enter an amount (e.g. ₹50)
3. Click Pay — the mock payment completes instantly
4. Wallet is credited immediately (no webhook wait)

**Via API:**
```bash
# 1. Create tip + mock Razorpay order
curl -X POST https://fliq.co.in/tips \
  -H "Content-Type: application/json" \
  -d '{
    "providerId": "<WORKER_USER_ID>",
    "amountPaise": 5000,
    "source": "PAYMENT_LINK",
    "message": "Test tip"
  }'
# Response: {"tipId":"...", "orderId":"mock_order_...", "amount":5000, ...}

# 2. Verify payment (mock values accepted)
curl -X POST https://fliq.co.in/tips/<TIP_ID>/verify \
  -H "Content-Type: application/json" \
  -d '{
    "razorpay_order_id": "<ORDER_ID_FROM_ABOVE>",
    "razorpay_payment_id": "mock_pay_test",
    "razorpay_signature": "mock_sig"
  }'
# Response: {"status":"verified","tipId":"...","bypass":true}
# Wallet is immediately credited — no webhook needed!
```

**Authenticated tip (linked to tipper account):**
```bash
curl -X POST https://fliq.co.in/tips/authenticated \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "providerId": "<WORKER_USER_ID>",
    "amountPaise": 10000,
    "source": "PAYMENT_LINK",
    "message": "Authenticated test tip"
  }'
```

---

### D. Wallet & Balance

```bash
# Check tip history as provider
curl https://fliq.co.in/tips/provider \
  -H "Authorization: Bearer $WORKER_TOKEN"

# Check tips given as customer
curl https://fliq.co.in/tips/customer \
  -H "Authorization: Bearer $TIPPER_TOKEN"
```

---

### E. Payouts

```bash
# Request payout (worker must have wallet balance)
curl -X POST https://fliq.co.in/payouts \
  -H "Authorization: Bearer $WORKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amountPaise": 50000,
    "mode": "UPI"
  }'

# View payout history
curl https://fliq.co.in/payouts/history \
  -H "Authorization: Bearer $WORKER_TOKEN"
```

> Note: With `DEV_BYPASS_ENABLED=true` and no Razorpay keys, payout creation to Razorpay will fail. The payout record is created in PENDING_BATCH status. Use the admin batch trigger to process.

---

### F. Payment Links

```bash
# Create a new payment link (as worker/provider)
curl -X POST https://fliq.co.in/payment-links \
  -H "Authorization: Bearer $WORKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "Chef",
    "workplace": "Test Cafe",
    "description": "Test Chef tip link",
    "suggestedAmountPaise": 3000,
    "allowCustomAmount": true
  }'

# List my payment links
curl https://fliq.co.in/payment-links/my \
  -H "Authorization: Bearer $WORKER_TOKEN"

# Resolve a payment link (public, used by tip page)
curl https://fliq.co.in/payment-links/testwrkr/resolve
```

---

### G. QR Codes

```bash
# List QR codes would be under provider profile
# The test worker already has a QR code created by /dev/seed
# To create a new one (requires Razorpay for real QR image):
curl -X POST https://fliq.co.in/qrcodes \
  -H "Authorization: Bearer $WORKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"locationLabel": "Table 2"}'
```

---

### H. Tip Jars

```bash
# Resolve the test tip jar
curl https://fliq.co.in/tip-jars/test-jar/resolve

# Create a new tip jar
curl -X POST https://fliq.co.in/tip-jars \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Team Birthday Fund",
    "eventType": "EVENT",
    "shortCode": "bday01",
    "targetAmountPaise": 200000
  }'

# Add a member to tip jar
curl -X POST https://fliq.co.in/tip-jars/<JAR_ID>/members \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"providerId": "<WORKER_USER_ID>", "splitPercentage": 100}'
```

---

### I. Recurring Tips

```bash
# Create a recurring tip mandate
curl -X POST https://fliq.co.in/recurring-tips \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "providerId": "<WORKER_USER_ID>",
    "amountPaise": 5000,
    "frequency": "MONTHLY"
  }'
# Note: Razorpay subscription creation will be mocked (returns mock subscription ID)

# List recurring tips
curl https://fliq.co.in/recurring-tips \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# Pause/cancel
curl -X PATCH https://fliq.co.in/recurring-tips/<RECURRING_TIP_ID> \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "cancel"}'
```

---

### J. Business Module

```bash
# List businesses owned by tipper
# (Test Cafe is auto-created by /dev/seed)

# Register a new business
curl -X POST https://fliq.co.in/businesses \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Test Restaurant",
    "type": "RESTAURANT",
    "contactPhone": "+919999999999"
  }'

# Get business details
curl https://fliq.co.in/businesses/<BUSINESS_ID> \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# Invite a team member
curl -X POST https://fliq.co.in/businesses/<BUSINESS_ID>/members/invite \
  -H "Authorization: Bearer $TIPPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919999999998", "role": "STAFF"}'
```

---

### K. Admin Dashboard

The Test Tipper (`+919999999999`) has ADMIN type and can access all admin endpoints.

```bash
# Platform stats
curl https://fliq.co.in/admin/stats \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# All tips
curl "https://fliq.co.in/admin/tips?page=1&limit=20" \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# All providers
curl "https://fliq.co.in/admin/providers?page=1&limit=20" \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# All payouts
curl "https://fliq.co.in/admin/payouts?page=1&limit=20" \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# Platform wallet balances
curl https://fliq.co.in/admin/wallets \
  -H "Authorization: Bearer $TIPPER_TOKEN"

# Trigger batch payout processing
curl -X POST https://fliq.co.in/admin/payouts/batch \
  -H "Authorization: Bearer $TIPPER_TOKEN"
```

---

### L. Gamification (Badges & Streaks)

Badges and streaks are automatically updated when tips are settled. After sending a few tips:

```bash
# Check user badges (via users/me or admin)
curl https://fliq.co.in/users/me \
  -H "Authorization: Bearer $TIPPER_TOKEN"
```

---

### M. Provider Profile

```bash
# Get public provider profile (no auth needed)
curl https://fliq.co.in/providers/<WORKER_USER_ID>/public

# Update provider profile (as worker)
curl -X PATCH https://fliq.co.in/providers/<WORKER_USER_ID> \
  -H "Authorization: Bearer $WORKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "Updated Worker Name",
    "bio": "Test bio updated",
    "upiVpa": "testworker@okicici"
  }'
```

---

## Getting User IDs

After seeding, get IDs from:
```bash
curl https://fliq.co.in/dev/status
```
Or from the `POST /dev/seed` response which returns both IDs.

Or via the login flow:
```bash
curl -X POST https://fliq.co.in/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919999999998", "code": "123456"}' | jq '.user.id'
```

---

## Full End-to-End Test Script

```bash
BASE=https://fliq.co.in

# 1. Seed
curl -X POST $BASE/dev/seed

# 2. Login as tipper
TIPPER_TOKEN=$(curl -s -X POST $BASE/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999999","code":"123456"}' | jq -r '.accessToken')

# 3. Login as worker
WORKER_TOKEN=$(curl -s -X POST $BASE/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999998","code":"123456"}' | jq -r '.accessToken')

WORKER_ID=$(curl -s $BASE/users/me -H "Authorization: Bearer $WORKER_TOKEN" | jq -r '.id')

# 4. Create + verify a mock tip
TIP=$(curl -s -X POST $BASE/tips \
  -H "Content-Type: application/json" \
  -d "{\"providerId\":\"$WORKER_ID\",\"amountPaise\":5000,\"source\":\"PAYMENT_LINK\"}")
TIP_ID=$(echo $TIP | jq -r '.tipId')
ORDER_ID=$(echo $TIP | jq -r '.orderId')

curl -s -X POST $BASE/tips/$TIP_ID/verify \
  -H "Content-Type: application/json" \
  -d "{\"razorpay_order_id\":\"$ORDER_ID\",\"razorpay_payment_id\":\"mock_pay_e2e\",\"razorpay_signature\":\"mock_sig\"}"

# 5. Check worker wallet
curl -s $BASE/admin/wallets -H "Authorization: Bearer $TIPPER_TOKEN"

echo "All done! Full tip lifecycle completed without Razorpay."
```

---

## What Happens at Each Step

| Step | With Bypass | Without Bypass |
|------|-------------|----------------|
| Send OTP | Returns immediately, log shows "123456" | Sends real WhatsApp/SMS |
| Verify OTP | Any OTP for test phones; "123456" always works | Validates against DB record |
| Create tip | Returns mock order ID (`mock_order_*`) | Creates real Razorpay order |
| Verify payment | Mock order: skips signature check, settles immediately | Verifies HMAC signature |
| Wallet credited | Immediate (no webhook wait) | After Razorpay webhook fires |
| Payout | Record created; actual transfer skipped | Calls RazorpayX |

---

## Turning Off Bypass

Set `DEV_BYPASS_ENABLED=false` in Railway to revert to real Razorpay + OTP behavior.
Test accounts remain in the database and will require real OTPs after disabling.

---

## Security Note

`DEV_BYPASS_ENABLED=true` is intentionally safe for production use with **specific test phone numbers only**:
- Only `+919999999999` and `+919999999998` accept the magic OTP
- Real user phones are unaffected
- `/dev/seed` and `/dev/status` return 403 if bypass is disabled
- The test accounts and mock payment flow are isolated to these two phone numbers
