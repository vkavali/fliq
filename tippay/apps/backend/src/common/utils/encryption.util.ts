import * as crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // 96-bit IV recommended for GCM
const AUTH_TAG_LENGTH = 16;

/**
 * Encrypt a UTF-8 string using AES-256-GCM.
 *
 * Wire format (all concatenated into one Buffer):
 *   [ IV (12 bytes) | authTag (16 bytes) | ciphertext (variable) ]
 *
 * @param plaintext  The value to encrypt (e.g. Aadhaar VID, PAN).
 * @param keyHex     32-byte key as a 64-char hex string, from env var.
 * @returns          Buffer suitable for storing in a Prisma Bytes field.
 */
export function encrypt(plaintext: string, keyHex: string): Buffer {
  const key = Buffer.from(keyHex, 'hex');
  if (key.length !== 32) {
    throw new Error('Encryption key must be 32 bytes (64 hex chars)');
  }

  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv, {
    authTagLength: AUTH_TAG_LENGTH,
  });

  const encrypted = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();

  return Buffer.concat([iv, authTag, encrypted]);
}

/**
 * Decrypt a Buffer produced by {@link encrypt}.
 *
 * @param data    Raw bytes from the database.
 * @param keyHex  Same key used during encryption.
 * @returns       Original plaintext string.
 */
export function decrypt(data: Buffer, keyHex: string): string {
  const key = Buffer.from(keyHex, 'hex');
  if (key.length !== 32) {
    throw new Error('Encryption key must be 32 bytes (64 hex chars)');
  }

  const iv = data.subarray(0, IV_LENGTH);
  const authTag = data.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH);
  const ciphertext = data.subarray(IV_LENGTH + AUTH_TAG_LENGTH);

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv, {
    authTagLength: AUTH_TAG_LENGTH,
  });
  decipher.setAuthTag(authTag);

  return decipher.update(ciphertext) + decipher.final('utf8');
}

// Aliases for backwards compatibility with providers.service.ts
export const encryptToBuffer = encrypt;
export const decryptFromBuffer = decrypt;
