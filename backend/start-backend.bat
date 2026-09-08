@echo off
chcp 65001 >nul
title Morok VPN Backend

echo.
echo ========================================
echo   Morok VPN Backend - Запуск
echo ========================================
echo.

REM Проверка Node.js
where node >nul 2>nul
if errorlevel 1 (
    echo [ОШИБКА] Node.js не найден!
    echo Скачай с https://nodejs.org
    pause
    exit /b 1
)

echo [OK] Node.js установлен: 
node --version
echo.

REM Установка зависимостей
echo [1/4] Установка зависимостей...
call npm install
if errorlevel 1 (
    echo [ОШИБКА] npm install failed
    pause
    exit /b 1
)

REM Prisma generate
echo.
echo [2/4] Генерация Prisma клиент...
call npx prisma generate
if errorlevel 1 (
    echo [ОШИБКА] prisma generate failed
    pause
    exit /b 1
)

REM Миграции
echo.
echo [3/4] Применение миграций...
call npx prisma migrate deploy
if errorlevel 1 (
    echo [ОШИБКА] prisma migrate failed
    echo Убедись что PostgreSQL запущен и база morok_vpn создана
    pause
    exit /b 1
)

REM Запуск
echo.
echo [4/4] Запуск backend...
echo.
echo ========================================
echo   Backend запущен на порту 3000
echo   API: http://localhost:3000/api
echo   Health: http://localhost:3000/api/health
echo ========================================
echo.
echo Нажми Ctrl+C для остановки
echo.

call npm run start:dev
