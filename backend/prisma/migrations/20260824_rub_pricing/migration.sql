-- Переход на рублёвое ценообразование.
--
-- 1) Валюта по умолчанию USD → RUB для тарифов и платёжных транзакций.
-- 2) Существующие тарифы переводятся на утверждённые цены:
--       30 дней   199 ₽
--       90 дней   499 ₽
--      365 дней  1490 ₽
-- 3) Пожизненный тариф снимается с продажи (isActive = false), но НЕ удаляется:
--    на него могут ссылаться прошлые платежи и подписки.
--
-- Прошлые транзакции сохраняют свою валюту — это исторические записи,
-- переписывать их нельзя.

ALTER TABLE "SubscriptionPlan" ALTER COLUMN "currency" SET DEFAULT 'RUB';
ALTER TABLE "PaymentTransaction" ALTER COLUMN "currency" SET DEFAULT 'RUB';

UPDATE "SubscriptionPlan"
   SET "price" = 199, "currency" = 'RUB', "durationDays" = 30, "isActive" = true
 WHERE "code" = 'MONTHLY';

UPDATE "SubscriptionPlan"
   SET "price" = 499, "currency" = 'RUB', "durationDays" = 90, "isActive" = true
 WHERE "code" = 'QUARTERLY';

UPDATE "SubscriptionPlan"
   SET "price" = 1490, "currency" = 'RUB', "durationDays" = 365, "isActive" = true
 WHERE "code" = 'YEARLY';

UPDATE "SubscriptionPlan"
   SET "isActive" = false
 WHERE "code" = 'LIFETIME';
