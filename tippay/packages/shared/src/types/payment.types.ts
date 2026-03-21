export enum PaymentMethod {
  UPI = 'UPI',
  CARD = 'CARD',
  NET_BANKING = 'NET_BANKING',
  WALLET = 'WALLET',
}

export enum TransactionType {
  TIP = 'TIP',
  PAYOUT = 'PAYOUT',
  REFUND = 'REFUND',
  COMMISSION = 'COMMISSION',
  TAX_DEDUCTION = 'TAX_DEDUCTION',
}

export enum TransactionStatus {
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
  REVERSED = 'REVERSED',
}

export enum PayoutMode {
  UPI = 'UPI',
  IMPS = 'IMPS',
  NEFT = 'NEFT',
}

export enum PayoutStatus {
  PENDING_BATCH = 'PENDING_BATCH',
  INITIATED = 'INITIATED',
  PROCESSED = 'PROCESSED',
  SETTLED = 'SETTLED',
  FAILED = 'FAILED',
}

export enum WalletType {
  PROVIDER_EARNINGS = 'PROVIDER_EARNINGS',
  PLATFORM_COMMISSION = 'PLATFORM_COMMISSION',
  TAX_RESERVE = 'TAX_RESERVE',
}

export enum LedgerEntryType {
  DEBIT = 'DEBIT',
  CREDIT = 'CREDIT',
}
