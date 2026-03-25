import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const ALGORITHM = 'aes-256-cbc';
const IV_LENGTH = 16;
// Key must be 32 bytes = 64 hex chars from ENCRYPTION_KEY env var

/**
 * Encrypt plaintext to a Buffer (IV prepended).
 * Stored as Prisma `Bytes` (bytea in PostgreSQL).
 */
export function encryptToBuffer(plaintext: string, hexKey: string): Buffer {
  const key = Buffer.from(hexKey, 'hex');
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return Buffer.concat([iv, encrypted]);
}

/**
 * Decrypt a Buffer (with prepended IV) back to plaintext string.
 */
export function decryptFromBuffer(data: Buffer, hexKey: string): string {
  const key = Buffer.from(hexKey, 'hex');
  const iv = data.subarray(0, IV_LENGTH);
  const encrypted = data.subarray(IV_LENGTH);
  const decipher = createDecipheriv(ALGORITHM, key, iv);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}
