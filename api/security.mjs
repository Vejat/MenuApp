import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

export const token = () => randomBytes(32).toString('base64url');
export const digest = value => createHash('sha256').update(value).digest('hex');

export function passwordHash(password, salt = randomBytes(16).toString('hex')) {
  return `${salt}:${scryptSync(password, salt, 64).toString('hex')}`;
}

export function verifyPassword(password, stored) {
  if (!stored) return false;
  return timingSafeEqual(Buffer.from(passwordHash(password, stored.split(':')[0])), Buffer.from(stored));
}
