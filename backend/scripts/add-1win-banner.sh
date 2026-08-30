#!/bin/bash
# Скрипт для создания баннера 1win через API
# Запустить после того как backend запущен

BACKEND_URL="${BACKEND_URL:-http://localhost:3000/api}"
ADMIN_TOKEN="$1"

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Использование: $0 <ADMIN_JWT_TOKEN>"
  echo ""
  echo "Получить токен:"
  echo "  1. Зайти в админ-панель приложения"
  echo "  2. Открыть DevTools → Application → Local Storage"
  echo "  3. Скопировать значение nexa_auth_token"
  exit 1
fi

echo "Создаю баннер 1win..."

# Создаём баннер
RESPONSE=$(curl -s -X POST "$BACKEND_URL/banners" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "title": "1win - Welcome Bonus",
    "description": "Получи бонус 2000 USDT при регистрации с промокодом LUDOSTAYA",
    "imageUrl": "/uploads/ludostaya-1win.jpg",
    "buttonText": "Получить бонус",
    "targetUrl": null,
    "referralCode": "LUDOSTAYA",
    "placement": "home",
    "sortOrder": 0,
    "displayDuration": 30,
    "active": true
  }')

echo "Ответ API:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

BANNER_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

if [ -z "$BANNER_ID" ]; then
  echo "❌ Ошибка создания баннера"
  exit 1
fi

echo ""
echo "✅ Баннер создан! ID: $BANNER_ID"
echo "📁 Изображение: $BACKEND_URL/uploads/ludostaya-1win.jpg"
echo ""
echo "⚠️  ВАЖНО: добавь targetUrl в баннере через админ-панель"
echo "   (ссылка на 1win с промокодом, например https://1win.com/?ref=LUDOSTAYA)"
