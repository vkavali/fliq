/**
 * Commission rates for the TipPay platform.
 *
 * Tips <= ZERO_COMMISSION_THRESHOLD_PAISE: 0% commission (builds trust).
 * Tips > threshold: DEFAULT_COMMISSION_RATE commission.
 * GST at 18% is applied on the commission amount.
 */

/** Tips at or below this amount (in paise) have 0% commission. Rs 100 = 10000 paise. */
export const ZERO_COMMISSION_THRESHOLD_PAISE = 10_000;

/** Default commission rate as a decimal. 5% = 0.05. */
export const DEFAULT_COMMISSION_RATE = 0.05;

/** GST rate on platform commission. 18% = 0.18. */
export const GST_RATE_ON_COMMISSION = 0.18;

/** TDS rate under Section 194O (1% of gross amount above threshold). */
export const TDS_RATE_194O = 0.01;

/** TDS threshold per provider per financial year (in paise). Rs 5,00,000 = 50000000 paise. */
export const TDS_THRESHOLD_PAISE = 50_000_000;

/** TCS rate under Section 52 CGST (1% of net taxable supplies). */
export const TCS_RATE = 0.01;

/** Minimum tip amount (in paise). Rs 10 = 1000 paise. */
export const MIN_TIP_AMOUNT_PAISE = 1_000;

/** Maximum tip amount (in paise). Rs 10,000 = 1000000 paise. */
export const MAX_TIP_AMOUNT_PAISE = 1_000_000;

/** Minimum payout amount (in paise). Rs 100 = 10000 paise. */
export const MIN_PAYOUT_AMOUNT_PAISE = 10_000;
