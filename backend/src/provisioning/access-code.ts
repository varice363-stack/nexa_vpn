import { randomInt } from 'crypto';

/**
 * Alphabet for redemption codes.
 *
 * Excludes characters people confuse when retyping from a screenshot or a
 * chat message: 0/O, 1/I/L, 5/S, 8/B. Support tickets about "the code does
 * not work" are almost always transcription errors, not real failures.
 */
const ALPHABET = '234679ACDEFGHJKMNPQRTUVWXYZ';

const GROUP = 4;
const GROUPS = 2;

/** Prefix makes the code recognisable when pasted anywhere. */
export const CODE_PREFIX = 'NEXA';

/**
 * Generates a code like `NEXA-7QK2-M4XP`.
 *
 * Uses `randomInt` (CSPRNG) rather than Math.random: these codes are
 * bearer credentials — anyone holding one gets paid access.
 */
export function generateAccessCode(): string {
  const groups: string[] = [];
  for (let g = 0; g < GROUPS; g++) {
    let chunk = '';
    for (let i = 0; i < GROUP; i++) {
      chunk += ALPHABET[randomInt(ALPHABET.length)];
    }
    groups.push(chunk);
  }
  return `${CODE_PREFIX}-${groups.join('-')}`;
}

/**
 * Normalises user input to the canonical stored form.
 *
 * Accepts what people actually type: lowercase, missing dashes, extra
 * spaces and a missing prefix. Characters outside the alphabet are left
 * as-is so the database lookup simply misses and the user gets a clear
 * "code not found" instead of a silent wrong match.
 */
export function normaliseAccessCode(input: string): string {
  const cleaned = input
    .toUpperCase()
    .replace(/\s+/g, '')
    .replace(/[^A-Z0-9]/g, '');

  const body = cleaned.startsWith(CODE_PREFIX)
    ? cleaned.slice(CODE_PREFIX.length)
    : cleaned;

  if (body.length !== GROUP * GROUPS) return '';

  const groups: string[] = [];
  for (let i = 0; i < body.length; i += GROUP) {
    groups.push(body.slice(i, i + GROUP));
  }
  return `${CODE_PREFIX}-${groups.join('-')}`;
}

/**
 * Recovery codes: `NEXA-XXXX-XXXX-XXXX-XXXX`.
 *
 * An account is optional in this product — a buyer never has to hand over an
 * email address. A recovery code is what lets them get their keys back after
 * a reinstall or on a second device, and it is the only identifier we hold.
 *
 * Four groups rather than two: a redemption code is worth one subscription,
 * but this one is worth every purchase the holder ever made, so guessing it
 * must be out of reach. 16 characters over a 27-symbol alphabet is ~76 bits.
 */
const RECOVERY_GROUPS = 4;

export function generateRecoveryCode(): string {
  const groups: string[] = [];
  for (let g = 0; g < RECOVERY_GROUPS; g++) {
    let chunk = '';
    for (let i = 0; i < GROUP; i++) {
      chunk += ALPHABET[randomInt(ALPHABET.length)];
    }
    groups.push(chunk);
  }
  return `${CODE_PREFIX}-${groups.join('-')}`;
}

/** Normalises a recovery code, tolerating the same sloppy input. */
export function normaliseRecoveryCode(input: string): string {
  const cleaned = input
    .toUpperCase()
    .replace(/\s+/g, '')
    .replace(/[^A-Z0-9]/g, '');

  const body = cleaned.startsWith(CODE_PREFIX)
    ? cleaned.slice(CODE_PREFIX.length)
    : cleaned;

  if (body.length !== GROUP * RECOVERY_GROUPS) return '';

  const groups: string[] = [];
  for (let i = 0; i < body.length; i += GROUP) {
    groups.push(body.slice(i, i + GROUP));
  }
  return `${CODE_PREFIX}-${groups.join('-')}`;
}
