import {
  generateAccessCode,
  normaliseAccessCode,
  generateRecoveryCode,
  normaliseRecoveryCode,
} from './access-code';

describe('access codes', () => {
  describe('generateAccessCode', () => {
    it('produces the NEXA-XXXX-XXXX shape', () => {
      expect(generateAccessCode()).toMatch(/^NEXA-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
    });

    it('never emits characters people misread', () => {
      // 0/O, 1/I/L, 5/S and 8/B are the classic transcription failures.
      const banned = /[01>58BILOS]/;
      for (let i = 0; i < 300; i++) {
        const body = generateAccessCode().replace('NEXA-', '');
        expect(body).not.toMatch(banned);
      }
    });

    it('does not repeat itself in a small batch', () => {
      const codes = new Set(
        Array.from({ length: 500 }, () => generateAccessCode()),
      );
      expect(codes.size).toBe(500);
    });
  });

  describe('normaliseAccessCode', () => {
    const canonical = 'NEXA-7QK2-M4XP';

    it('accepts the canonical form unchanged', () => {
      expect(normaliseAccessCode(canonical)).toBe(canonical);
    });

    it('accepts what users actually type', () => {
      for (const input of [
        'nexa-7qk2-m4xp',
        'NEXA7QK2M4XP',
        '  NEXA-7QK2-M4XP  ',
        'nexa 7qk2 m4xp',
        '7QK2-M4XP',
        '7qk2m4xp',
      ]) {
        expect(normaliseAccessCode(input)).toBe(canonical);
      }
    });

    it('rejects the wrong length instead of guessing', () => {
      for (const bad of ['NEXA-7QK2', '7QK2', '', 'NEXA-7QK2-M4XP-EXTRA']) {
        expect(normaliseAccessCode(bad)).toBe('');
      }
    });
  });
});

describe('recovery codes', () => {
  it('generates the NEXA-XXXX-XXXX-XXXX-XXXX shape', () => {
    const code = generateRecoveryCode();
    expect(code).toMatch(/^NEXA-[234679ACDEFGHJKMNPQRTUVWXYZ]{4}(-[234679ACDEFGHJKMNPQRTUVWXYZ]{4}){3}$/);
  });

  it('is long enough to be worth protecting every purchase', () => {
    // 16 symbols over a 27-char alphabet ~= 76 bits; a redemption code is 8.
    const body = generateRecoveryCode().replace(/^NEXA-/, '').replace(/-/g, '');
    expect(body).toHaveLength(16);
  });

  it('never repeats across a large sample', () => {
    const seen = new Set(Array.from({ length: 500 }, () => generateRecoveryCode()));
    expect(seen.size).toBe(500);
  });

  it('accepts the sloppy input people actually type', () => {
    const code = generateRecoveryCode();
    const body = code.replace(/^NEXA-/, '').replace(/-/g, '');
    for (const variant of [
      code.toLowerCase(),
      `  ${code}  `,
      body,
      body.toLowerCase(),
      `nexa ${body}`,
    ]) {
      expect(normaliseRecoveryCode(variant)).toBe(code);
    }
  });

  it('rejects a redemption code — the two must not be confused', () => {
    // A redemption code is 8 chars; feeding it here must fail rather than
    // silently resolve to someone's whole account.
    expect(normaliseRecoveryCode(generateAccessCode())).toBe('');
  });

  it('rejects wrong lengths', () => {
    expect(normaliseRecoveryCode('NEXA-7QK2-M4XP-99')).toBe('');
    expect(normaliseRecoveryCode('')).toBe('');
  });
});
