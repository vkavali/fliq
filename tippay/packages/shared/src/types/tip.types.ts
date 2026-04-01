export enum TipSource {
  QR_CODE = 'QR_CODE',
  PAYMENT_LINK = 'PAYMENT_LINK',
  IN_APP = 'IN_APP',
}

export enum TipStatus {
  INITIATED = 'INITIATED',
  PAID = 'PAID',
  SETTLED = 'SETTLED',
  FAILED = 'FAILED',
  REFUNDED = 'REFUNDED',
}

export enum QrCodeType {
  STATIC = 'STATIC',
  DYNAMIC = 'DYNAMIC',
}

/**
 * Structured intent — the reason for appreciation.
 * Adds semantic meaning to each tip beyond just an amount.
 */
export enum TipIntent {
  KINDNESS = 'KINDNESS',
  SPEED = 'SPEED',
  EXPERIENCE = 'EXPERIENCE',
  SUPPORT = 'SUPPORT',
}
