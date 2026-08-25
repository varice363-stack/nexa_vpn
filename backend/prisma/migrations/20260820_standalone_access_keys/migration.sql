-- TASK #021 — hybrid auth: access keys that work without an account.
--
-- Idempotent so it can be re-run safely on an existing database.

-- 1. userId becomes optional: a key may exist before anyone registers.
ALTER TABLE "AccessKey" ALTER COLUMN "userId" DROP NOT NULL;

-- 2. Redemption code handed to the buyer (NEXA-XXXX-XXXX).
ALTER TABLE "AccessKey" ADD COLUMN IF NOT EXISTS "code" TEXT;
ALTER TABLE "AccessKey" ADD COLUMN IF NOT EXISTS "activatedAt" TIMESTAMP(3);

-- 3. Device fingerprint from an anonymous client. Deliberately NOT a foreign
--    key: the Device table only holds devices of registered accounts, and a
--    code can be redeemed with no account at all.
ALTER TABLE "AccessKey" ADD COLUMN IF NOT EXISTS "boundDevice" TEXT;

-- 4. Codes must be unique, but many rows legitimately have NULL.
CREATE UNIQUE INDEX IF NOT EXISTS "AccessKey_code_key"
  ON "AccessKey" ("code");

CREATE INDEX IF NOT EXISTS "AccessKey_code_idx"
  ON "AccessKey" ("code");
