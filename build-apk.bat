@echo off
chcp 65001 >nul
title Morok VPN - Сборка APK

echo.
echo ========================================
echo   Morok VPN - Сборка APK
echo ========================================
echo.

REM Проверка Flutter
where flutter >nul 2>nul
if errorlevel 1 (
    echo [ОШИБКА] Flutter не найден!
    echo Убедись что Flutter добавлен в PATH
    pause
    exit /b 1
)

echo [OK] Flutter установлен:
flutter --version | findstr "Flutter"
echo.

REM Очистка
echo [1/3] Очистка...
call flutter clean
call flutter pub get
echo.

REM Выбор типа сборки
echo Выбери тип сборки:
echo   1 - Debug (с админским доступом)
echo   2 - Release (без админского доступа)
echo.
set /p BUILD_TYPE="Введи 1 или 2: "

if "%BUILD_TYPE%"=="1" goto debug
if "%BUILD_TYPE%"=="2" goto release

echo [ОШИБКА] Неверный выбор
pause
exit /b 1

:debug
echo.
echo [2/3] Debug сборка...
echo [OK] Админ код: NEXA-66AB-AV3H-9HSJ-R8VZ
echo [OK] API URL: http://10.0.2.2:3000/api
echo.
call flutter build apk --debug --dart-define=OWNER_CODE=NEXA-66AB-AV3H-9HSJ-R8VZ --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
goto done

:release
echo.
echo [2/3] Release сборка...
echo [ВНИМАНИЕ] Админский доступ НЕ будет работать!
echo.
call flutter build apk --release --dart-define=API_BASE_URL=https://api.morokvpn.app
goto done

:done
if errorlevel 1 (
    echo.
    echo [ОШИБКА] Сборка не удалась!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Сборка успешна!
echo ========================================
echo.

if "%BUILD_TYPE%"=="1" (
    set APK_PATH=build\app\outputs\flutter-apk\app-debug.apk
) else (
    set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
)

echo APK: %APK_PATH%

if exist "%APK_PATH%" (
    for %%A in ("%APK_PATH%") do echo Размер: %%~zA байт
)

echo.
echo Для установки на устройство:
echo   flutter install
echo.
pause
