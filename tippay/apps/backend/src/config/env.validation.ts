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

  JWT_SECRET: Joi.string().optional().min(16).messages({
    'string.min': 'JWT_SECRET must be at least 16 characters',
  }),

  RAZORPAY_KEY_ID: Joi.string().optional(),
  RAZORPAY_KEY_SECRET: Joi.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: Joi.string().optional(),

  // WhatsApp Business API (Meta Cloud API)
  WHATSAPP_ACCESS_TOKEN: Joi.string().optional(),
  WHATSAPP_PHONE_NUMBER_ID: Joi.string().optional(),
  WHATSAPP_APP_SECRET: Joi.string().optional(),
  WHATSAPP_WEBHOOK_VERIFY_TOKEN: Joi.string().optional().default('fliq_whatsapp_verify'),
}).options({ allowUnknown: true });
