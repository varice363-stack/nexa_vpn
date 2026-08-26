-- AlterTable
ALTER TABLE "Banner" ADD COLUMN "referralCode" TEXT;
ALTER TABLE "Banner" ADD COLUMN "displayDuration" INTEGER NOT NULL DEFAULT 30;
