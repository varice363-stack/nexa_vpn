-- Приглашение друга: вместо процентов с оплаты приглашённый получает неделю
-- бесплатного доступа. Здесь храним, кто кого привёл, и когда приглашение
-- применили (одно на устройство).
ALTER TABLE "User" ADD COLUMN "referredBy" TEXT;
ALTER TABLE "User" ADD COLUMN "referralAppliedAt" TIMESTAMP(3);

CREATE INDEX "User_referredBy_idx" ON "User"("referredBy");
