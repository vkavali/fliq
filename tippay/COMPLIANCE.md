# Fliq — Compliance & Regulatory Status

> **Last Updated:** April 2026
> **Applicable Jurisdictions:** India (primary), United States (testing only)
> **Entity Status:** Pre-incorporation — Indian Pvt. Ltd. pending

---

## 1. Indian Laws & Regulations

### ✅ Digital Personal Data Protection Act, 2023 (DPDP Act)

| Section | Requirement | Status | Implementation |
|---|---|---|---|
| §5 | Lawful purpose for processing | ✅ Covered | Only process data needed for tipping service |
| §6 | Consent — explicit, informed, specific | ✅ Covered | Auto-logged on signup for 4 purposes via `ConsentRecord` table |
| §6 | Consent — easy withdrawal | ✅ Covered | `DELETE /users/me/consents/:purpose` |
| §6 | Notice in plain language | ✅ Covered | `/privacy.html` — plain language summary at top |
| §6 | Notice in scheduled languages | ⚠️ Partial | English only — Hindi and Telugu translations pending |
| §8(1) | Right to Access (data summary) | ✅ Covered | `GET /users/me/data-export` — structured JSON |
| §8(3) | Right to Correction | ✅ Covered | `PATCH /users/me` — profile update |
| §8(4) | Right to Erasure | ✅ Covered | `DELETE /users/me` — PII erased, transactions anonymised |
| §8(5) | Right to Nominate | ❌ Not covered | Nomination feature not yet built |
| §8(7) | Grievance Redressal | ✅ Covered | `POST /users/me/grievance` — 72hr SLA |
| §9 | Data Fiduciary obligations | ✅ Covered | Purpose limitation, data minimization in schema |
| §10 | Data Processor obligations | ✅ Covered | Razorpay acts as processor — governed by their DPA |
| §11 | Data retention limits | ✅ Covered | OTPs: 5min, deleted accounts: 30 days, transactions: 7yr (tax) |
| §15 | Breach notification to DPB | ⚠️ Planned | Logging infrastructure exists, formal notification SOP pending |
| §16 | Cross-border transfer | ✅ Covered | Disclosed in privacy policy; US not on restricted list |
| §17 | Exemptions (state, research) | N/A | Not applicable |
| §21 | Significant Data Fiduciary | N/A | Not designated (applies to large-scale processors) |

### ✅ Information Technology Act, 2000

| Section | Requirement | Status | Implementation |
|---|---|---|---|
| §43A | Reasonable security practices | ✅ Covered | PAN & bank account encrypted at app level, HTTPS/TLS, no passwords stored |
| §72A | Disclosure of personal data | ✅ Covered | No sale/sharing of data with third parties |
| Rule 4 (IT Rules 2011) | Privacy policy publication | ✅ Covered | `/privacy.html` |
| Rule 5 | Body corporate — sensitive data | ✅ Covered | Financial data encrypted; biometrics/Aadhaar not collected |
| Rule 8 | Grievance officer designation | ⚠️ Partial | Endpoint built; named officer pending (needs company formation) |

### ✅ RBI Data Localization (Circular DPSS.CO.OD No.2785/2018)

| Requirement | Status | Notes |
|---|---|---|
| Payment system data stored in India | ✅ N/A to Fliq | Fliq is a **merchant**, not a Payment System Operator (PSO). Razorpay (the PSO) is responsible for storing payment data in India. |
| Card/UPI data never stored by Fliq | ✅ Confirmed | Fliq database has zero payment instrument fields — all handled by Razorpay checkout |
| Business data (profiles, tips) in US | ✅ Permissible | No RBI restriction on merchant business data location |

### ✅ RBI Payment Aggregator Regulations

| Requirement | Status | Notes |
|---|---|---|
| PA License required? | ✅ Not required | Fliq uses Razorpay's PA license. Money flows: Customer → Razorpay → Provider. Fliq never holds/pools funds. |
| Net worth ₹15 crore? | N/A | Only for PA license holders |
| Escrow account? | N/A | Only if Fliq held funds (it doesn't) |

### ⚠️ Goods & Services Tax (GST)

| Requirement | Status | Notes |
|---|---|---|
| GST registration | ❌ Pending | Required once Indian Pvt. Ltd. is incorporated |
| GST on platform fees | ⚠️ Future | Currently 0% commission — will need GST when fees are introduced |
| TDS on provider payouts | ✅ Schema ready | `tdsPaise` field in Tip model — implementation pending actual launch |

---

## 2. Apple App Store Requirements

| Guideline | Requirement | Status | Implementation |
|---|---|---|---|
| 5.1.1(v) | Account deletion from within app | ✅ Covered | `DELETE /users/me` — callable from in-app settings |
| 5.1.1 | Privacy policy link | ✅ Covered | `/privacy.html` — linked in app metadata |
| 5.1.2 | Data use and sharing disclosure | ⚠️ Pending | Need to fill App Privacy Details in App Store Connect |
| 5.6.1 | Apps with Sign in with Apple | N/A | App uses OTP authentication, not Apple sign-in |

## 3. Google Play Store Requirements

| Policy | Requirement | Status | Implementation |
|---|---|---|---|
| User Data | In-app account & data deletion | ✅ Covered | `DELETE /users/me` |
| User Data | Web-based deletion option | ✅ Covered | `/delete-account.html` |
| Data Safety | Declare data collection practices | ⚠️ Pending | Need to fill Data Safety form in Play Console |
| Privacy Policy | Must be linked in store listing | ✅ Covered | `/privacy.html` |

---

## 4. GDPR Alignment (Best Practice — Not Legally Required for India-Only)

| Article | Requirement | Status | Notes |
|---|---|---|---|
| Art 6 | Lawful basis for processing | ✅ Covered | Consent-based |
| Art 7 | Conditions for consent | ✅ Covered | Explicit consent logged per purpose |
| Art 12-14 | Transparent information | ✅ Covered | Plain language privacy policy |
| Art 15 | Right of access | ✅ Covered | `GET /users/me/data-export` |
| Art 16 | Right to rectification | ✅ Covered | `PATCH /users/me` |
| Art 17 | Right to erasure | ✅ Covered | `DELETE /users/me` |
| Art 20 | Right to data portability | ✅ Covered | Structured JSON export |
| Art 21 | Right to object | ✅ Covered | Consent withdrawal per purpose |
| Art 33 | Breach notification (72hr) | ⚠️ Planned | SOP pending |
| Art 35 | DPIA | ❌ Not done | Not required until Significant Data Fiduciary designation |

---

## 5. Data Inventory

### What We Collect

| Data Category | Fields | Storage | Encrypted | Retention |
|---|---|---|---|---|
| Identity | Phone, email, name | PostgreSQL (Railway US) | At rest (DB encryption) | Until account deletion |
| Profile (Providers) | Display name, bio, avatar URL, category | PostgreSQL | No (public data) | Until account deletion |
| KYC | PAN, bank account number | PostgreSQL | ✅ App-level encryption (`Bytes` type) | Until account deletion |
| KYC metadata | Bank IFSC, UPI VPA, verification status | PostgreSQL | No | Until account deletion |
| Transactions | Tip amount, status, intent, message, rating | PostgreSQL | No | 7 years (tax/legal) |
| Payouts | Amount, status, UTR, mode | PostgreSQL | No | 7 years (tax/legal) |
| Device | FCM push token | PostgreSQL | No | Until account deletion |
| Auth | OTP codes | PostgreSQL | No | 5 minutes (auto-expire) |
| Consent | Purpose, grant/withdrawal timestamps | PostgreSQL | No | Indefinite (audit trail) |

### What We Do NOT Collect

- ❌ Credit/debit card numbers
- ❌ UPI PINs or passwords
- ❌ Aadhaar number
- ❌ Biometric data
- ❌ Location/GPS data
- ❌ Browsing history or cookies (mobile app)
- ❌ Contact list or call logs

### Third-Party Data Processors

| Processor | Data Shared | Purpose | Their Compliance |
|---|---|---|---|
| Razorpay | Order ID, amount | Payment processing | RBI PA license, PCI-DSS, data stored in India |
| Firebase (Google) | Device FCM token | Push notifications | SOC 2, ISO 27001, GDPR DPA available |
| WhatsApp/Gupshup | Phone number, OTP | Authentication | End-to-end encryption, Meta DPA |

---

## 6. API Endpoints — Compliance Features

```
GET    /users/me                    → View profile data
PATCH  /users/me                    → Correct/update personal data
GET    /users/me/data-export        → Export all personal data (DPDP §8, GDPR Art 15/20)
GET    /users/me/consents           → View consent records
DELETE /users/me/consents/:purpose  → Withdraw consent (DPDP §6)
POST   /users/me/grievance          → File data privacy grievance (DPDP §8(7))
DELETE /users/me                    → Delete account & erase PII (DPDP §8(4))
```

---

## 7. Outstanding Items

### 🔴 Must Do Before Launch

| Item | Blocker | Owner |
|---|---|---|
| Incorporate Indian Pvt. Ltd. company | Legal entity required for Razorpay merchant account | Founder + CA |
| Appoint resident Indian director | Companies Act 2013 requirement | Founder |
| Name a Grievance Officer | DPDP Act + IT Act requirement | Post-incorporation |
| Fill Apple App Privacy Details | App Store review requirement | Founder |
| Fill Google Play Data Safety form | Play Store requirement | Founder |
| PAN + GST registration | Tax compliance | CA |

### 🟡 Should Do Before Scale

| Item | Reason | Owner |
|---|---|---|
| Hindi/Telugu privacy policy translations | DPDP notice in scheduled languages | Legal/Translation |
| Breach notification SOP | DPDP §15 — notify DPB within 72 hours | Engineering + Legal |
| Data Protection Impact Assessment | Best practice (required if designated SDF) | Legal |
| Right to Nominate feature | DPDP §8(5) — nominate someone to exercise rights | Engineering |
| TDS implementation | Required when provider payouts start | Finance + Engineering |
| Formal DPA with Razorpay | Data processor agreement | Legal |

### 🟢 Nice to Have

| Item | Reason |
|---|---|
| Cookie consent banner (web) | Best practice for fliq.co.in website |
| Annual data audit | GDPR alignment, demonstrates good faith |
| Data retention auto-purge | Automatically delete 7yr+ transaction records |

---

## 8. Regulatory Contacts

| Authority | Jurisdiction | Website |
|---|---|---|
| Data Protection Board of India | DPDP Act enforcement | https://www.dpbi.gov.in |
| Reserve Bank of India | Payment system regulation | https://www.rbi.org.in |
| MeitY | IT Act, DPDP oversight | https://www.meity.gov.in |
| MCA (Registrar of Companies) | Company incorporation | https://www.mca.gov.in |
| GSTN | GST registration | https://www.gst.gov.in |

---

> **Disclaimer:** This document is maintained for internal tracking purposes and does not constitute legal advice. Consult qualified legal professionals for jurisdiction-specific compliance requirements.
