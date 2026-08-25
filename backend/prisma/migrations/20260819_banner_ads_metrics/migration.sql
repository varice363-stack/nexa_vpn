-- TASK #020 — banner ad metrics, click-through target and placement slots.

ALTER TABLE "Banner" ADD COLUMN IF NOT EXISTS "targetUrl"   TEXT;
ALTER TABLE "Banner" ADD COLUMN IF NOT EXISTS "placement"   TEXT    NOT NULL DEFAULT 'home';
ALTER TABLE "Banner" ADD COLUMN IF NOT EXISTS "sortOrder"   INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Banner" ADD COLUMN IF NOT EXISTS "impressions" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Banner" ADD COLUMN IF NOT EXISTS "clicks"      INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS "Banner_placement_active_idx" ON "Banner" ("placement", "active");
