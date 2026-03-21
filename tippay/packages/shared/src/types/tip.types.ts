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
