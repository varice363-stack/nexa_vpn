-- Лимит трафика для ключа в мегабайтах (NULL = без лимита).
-- Использование считает сборщик на хосте (xray api statsquery) и складывает
-- в /var/lib/morok/xray-stats.json; бэкенд лишь читает файл и сравнивает.
ALTER TABLE "AccessKey" ADD COLUMN "trafficLimitMb" INTEGER;
