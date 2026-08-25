-- Privacy: stop recording who connected where and when.
--
-- ConnectionLog tied a user's identity to a server, a timestamp and a traffic
-- volume. For a VPN that is exactly the data that must not exist: it can be
-- seized, leaked or subpoenaed. Nothing in the product needs it — the client
-- keeps its own session history locally, and billing works off
-- AccessKey.expiresAt.
--
-- Idempotent: safe to run on a database where it was already applied.

DROP TABLE IF EXISTS "ConnectionLog";

-- Accounts become optional. Access is normally tied to a recovery code, so a
-- buyer never has to hand over an email address.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'User' AND column_name = 'email'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE "User" ALTER COLUMN "email" DROP NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'User' AND column_name = 'passwordHash'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE "User" ALTER COLUMN "passwordHash" DROP NOT NULL;
  END IF;
END $$;
