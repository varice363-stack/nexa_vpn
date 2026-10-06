-- TASK #029: ручное подтверждение оплаты в USDT (TRC-20 / BEP-20).
-- Все колонки опциональны и не задепаты существующий flow (YooKassa/mock).
ALTER TABLE "PaymentTransaction"
  ADD COLUMN "cryptoAddress" TEXT,
  ADD COLUMN "cryptoNetwork" TEXT,
  ADD COLUMN "cryptoAmount" DOUBLE PRECISION,
  ADD COLUMN "cryptoExpiresAt" TIMESTAMP(3),
  ADD COLUMN "cryptoTxHash" TEXT,
  ADD COLUMN "cryptoSubmittedAt" TIMESTAMP(3),
  ADD COLUMN "cryptoReviewedNote" TEXT;

-- один хэш транзакции = одна оплата (защита от «оплатил одним хэшем двоих»)
CREATE UNIQUE INDEX "PaymentTransaction_cryptoTxHash_key" ON "PaymentTransaction"("cryptoTxHash");

-- очередь на подтверждение: PENDING-крипта, отсортированная по дате отправки
CREATE INDEX "PaymentTransaction_provider_status_cryptoSubmittedAt_idx"
  ON "PaymentTransaction"("provider", "status", "cryptoSubmittedAt");
