-- Признак устройства для защиты пробного периода от переустановки.
-- Это необратимый хеш (SHA-256 от идентификатора устройства), а не сам
-- идентификатор: сервер по нему только отличает одно устройство от другого.
ALTER TABLE "User" ADD COLUMN "deviceFingerprint" TEXT;

CREATE INDEX "User_deviceFingerprint_idx" ON "User"("deviceFingerprint");
