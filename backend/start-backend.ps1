# Backend startup script for Windows PowerShell
# Запуск: .\start-backend.ps1

Write-Host "🚀 Запуск Morok VPN Backend..." -ForegroundColor Cyan

# Проверка Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js не установлен. Скачай с https://nodejs.org" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Node.js версии $(node --version)" -ForegroundColor Green

# Установка зависимостей
Write-Host "`n📦 Установка зависимостей..." -ForegroundColor Yellow
npm install

# Prisma generate
Write-Host "`n Генерация Prisma клиент..." -ForegroundColor Yellow
npx prisma generate

# Проверка PostgreSQL
Write-Host "`n🗄️  Проверка PostgreSQL..." -ForegroundColor Yellow
try {
    $env:PGPASSWORD = "morok"
    psql -U morok -d morok_vpn -c "SELECT 1" -q 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ PostgreSQL подключен" -ForegroundColor Green
    } else {
        Write-Host "️  PostgreSQL недоступен. Убедись что:" -ForegroundColor Yellow
        Write-Host "   1. PostgreSQL установлен и запущен" -ForegroundColor Yellow
        Write-Host "   2. База данных 'morok_vpn' создана" -ForegroundColor Yellow
        Write-Host "   3. Пользователь 'morok' с паролем 'morok' создан" -ForegroundColor Yellow
        Write-Host "   4. DATABASE_URL в .env правильный" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ psql не найден. Установи PostgreSQL клиент." -ForegroundColor Red
    exit 1
}

# Миграции
Write-Host "`n Применение миграций..." -ForegroundColor Yellow
npx prisma migrate deploy

# Запуск
Write-Host "`n✅ Запуск backend на порту 3000..." -ForegroundColor Green
Write-Host "📡 API: http://localhost:3000/api" -ForegroundColor Cyan
Write-Host "🏥 Health: http://localhost:3000/api/health" -ForegroundColor Cyan
Write-Host "`n⏹️  Для остановки нажми Ctrl+C" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

npm run start:dev
