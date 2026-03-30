import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  APP_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),

  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),

  PORT: Joi.number().default(3000),

  DATABASE_URL: Joi.string().required().messages({
    'any.required': 'DATABASE_URL is required — set it in Railway or .env',
  }),

  JWT_SECRET: Joi.when('APP_ENV', {
    is: 'production',
    then: Joi.string().min(16).required().messages({
      'any.required': 'JWT_SECRET is required in production — set a strong random secret in Railway',
      'string.min': 'JWT_SECRET must be at least 16 characters',
    }),
    otherwise: Joi.string().min(16).default('fliq-dev-secret-not-for-production'),
  }),

  RAZORPAY_KEY_ID: Joi.string().optional(),
  RAZORPAY_KEY_SECRET: Joi.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: Joi.string().optional(),

  // Firebase Cloud Messaging (base64-encoded service account JSON)
  FIREBASE_SERVICE_ACCOUNT_BASE64: Joi.string().optional(),

  // AES-256 encryption key for PAN/bank account (64 hex chars = 32 bytes)
  ENCRYPTION_KEY: Joi.string().length(64).optional().messages({
    'string.length': 'ENCRYPTION_KEY must be exactly 64 hex characters (32 bytes)',
  }),

  // WhatsApp Business API (Meta Cloud API)
  WHATSAPP_ACCESS_TOKEN: Joi.string().optional(),
  WHATSAPP_PHONE_NUMBER_ID: Joi.string().optional(),
  WHATSAPP_APP_SECRET: Joi.string().optional(),
  WHATSAPP_WEBHOOK_VERIFY_TOKEN: Joi.string().optional().default('fliq_whatsapp_verify'),
  WHATSAPP_BUSINESS_ACCOUNT_ID: Joi.string().optional(),

  // OTP delivery channel: 'whatsapp' (default) or 'sms'
  OTP_CHANNEL: Joi.string().valid('whatsapp', 'sms').default('whatsapp'),
}).options({ allowUnknown: true });
