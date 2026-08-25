-- CreateTable: MasterCode (admin bootstrap)
-- One-time admin bootstrap code. Generated on first call to GET /auth/bootstrap
-- (when no ADMIN exists). The first user who registers with this code becomes
-- ADMIN. After use, the code is marked as consumed.

CREATE TABLE IF NOT EXISTS "MasterCode" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "usedBy" TEXT,
    "usedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MasterCode_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "MasterCode_code_key" ON "MasterCode"("code");
