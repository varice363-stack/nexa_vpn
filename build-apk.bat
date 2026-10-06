@echo off
chcp 65001 >nul
title MOROK VPN - Сборка APK
REM Двойной клик = релизный APK (без владелец-кода), для раздачи людям.
REM Нужен debug или свой код - запускай build.ps1 из терминала Android Studio.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
echo.
pause
