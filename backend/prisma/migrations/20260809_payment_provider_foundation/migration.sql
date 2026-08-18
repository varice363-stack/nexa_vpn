-- AlterTable
ALTER TABLE "PaymentTransaction" ADD COLUMN     "idempotencyKey" TEXT,
ADD COLUMN     "webhookEvent" TEXT,
ADD COLUMN     "webhookProcessedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "PaymentTransaction_idempotencyKey_idx" ON "PaymentTransaction"("idempotencyKey");

