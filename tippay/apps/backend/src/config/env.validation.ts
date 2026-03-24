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

  JWT_SECRET: Joi.string().required().min(16).messages({
    'any.required': 'JWT_SECRET is required — generate a strong random value',
    'string.min': 'JWT_SECRET must be at least 16 characters',
  }),

  RAZORPAY_KEY_ID: Joi.string().when('APP_ENV', {
    is: 'production',
    then: Joi.required().messages({
      'any.required': 'RAZORPAY_KEY_ID is required in production',
    }),
    otherwise: Joi.optional(),
  }),

  RAZORPAY_KEY_SECRET: Joi.string().when('APP_ENV', {
    is: 'production',
    then: Joi.required().messages({
      'any.required': 'RAZORPAY_KEY_SECRET is required in production',
    }),
    otherwise: Joi.optional(),
  }),

  RAZORPAY_WEBHOOK_SECRET: Joi.string().when('APP_ENV', {
    is: 'production',
    then: Joi.required().messages({
      'any.required': 'RAZORPAY_WEBHOOK_SECRET is required in production',
    }),
    otherwise: Joi.optional(),
  }),
}).options({ allowUnknown: true });
