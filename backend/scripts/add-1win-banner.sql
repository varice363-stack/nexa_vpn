-- Добавить баннер 1win в базу данных
-- Выполнить после миграции на локальной БД

INSERT INTO "Banner" (
  id,
  title,
  description,
  "imageUrl",
  "buttonText",
  "targetUrl",
  "referralCode",
  placement,
  "sortOrder",
  "displayDuration",
  impressions,
  clicks,
  active,
  "createdAt",
  "updatedAt"
) VALUES (
  gen_random_uuid(),
  '1win - Welcome Bonus',
  'Получи бонус 2000 USDT при регистрации с промокодом LUDOSTAYA',
  '/uploads/ludostaya-1win.jpg',
  'Получить бонус',
  NULL,  -- TODO: заменить на реальную ссылку 1win, например https://1win.com/?ref=LUDOSTAYA
  'LUDOSTAYA',
  'home',
  0,
  30,
  0,
  0,
  true,
  NOW(),
  NOW()
);
