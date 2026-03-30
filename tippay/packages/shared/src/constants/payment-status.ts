/**
 * Razorpay webhook event types the platform handles.
 */
export const RAZORPAY_EVENTS = {
  PAYMENT_AUTHORIZED: 'payment.authorized',
  PAYMENT_CAPTURED: 'payment.captured',
  PAYMENT_FAILED: 'payment.failed',
  ORDER_PAID: 'order.paid',
  TRANSFER_PROCESSED: 'transfer.processed',
  PAYOUT_PROCESSED: 'payout.processed',
  PAYOUT_FAILED: 'payout.failed',
  PAYOUT_REVERSED: 'payout.reversed',
  QR_CODE_CREDITED: 'qr_code.credited',
  // UPI Autopay / Subscription events
  SUBSCRIPTION_AUTHENTICATED: 'subscription.authenticated',
  SUBSCRIPTION_CHARGED: 'subscription.charged',
  SUBSCRIPTION_CANCELLED: 'subscription.cancelled',
  SUBSCRIPTION_HALTED: 'subscription.halted',
  SUBSCRIPTION_PENDING: 'subscription.pending',
} as const;

/**
 * Kafka topic names used by the platform.
 */
export const KAFKA_TOPICS = {
  TIP_EVENTS: 'tip.events',
  PAYOUT_EVENTS: 'payout.events',
  NOTIFICATION_EVENTS: 'notification.events',
} as const;

/**
 * Supported currency.
 */
export const CURRENCY = 'INR' as const;
