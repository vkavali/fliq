/**
 * All monetary amounts in the system are stored as integer paise.
 * Rs 100.50 = 10050 paise. This avoids floating-point precision errors.
 */

/** Convert rupees (number) to paise (integer). */
export function rupeesToPaise(rupees: number): number {
  return Math.round(rupees * 100);
}

/** Convert paise (integer) to rupees (number). */
export function paiseToRupees(paise: number): number {
  return paise / 100;
}

/**
 * Format paise as a human-readable INR string.
 * formatPaise(10050) => "₹100.50"
 * formatPaise(10000) => "₹100.00"
 */
export function formatPaise(paise: number): string {
  const rupees = paiseToRupees(paise);
  return `₹${rupees.toFixed(2)}`;
}

/**
 * Calculate commission on a tip amount.
 * Returns 0 if amount is at or below the zero-commission threshold.
 */
export function calculateCommission(
  amountPaise: number,
  thresholdPaise: number,
  rate: number,
): number {
  if (amountPaise <= thresholdPaise) {
    return 0;
  }
  return Math.round(amountPaise * rate);
}

/**
 * Calculate GST on a commission amount.
 */
export function calculateGstOnCommission(
  commissionPaise: number,
  gstRate: number,
): number {
  return Math.round(commissionPaise * gstRate);
}
