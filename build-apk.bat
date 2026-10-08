@echo off
setlocal
title MOROK VPN - APK build
REM ============================================================
REM  One command: updates the code from GitHub, then builds APK.
REM
REM  Owner build (with admin panel):
REM      build-apk.bat MOROK-XXXX-XXXX-XXXX-XXXX
REM  Public build (for customers, no admin panel):
REM      build-apk.bat
REM
REM  Result: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
REM ============================================================

set OWNER=%~1

where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Flutter not found in PATH.
  echo         Open the terminal inside Android Studio and run this file there.
  exit /b 1
)

echo.
echo [1/4] Updating code from GitHub...
git stash --include-untracked >nul 2>&1
git fetch origin
git checkout main >nul 2>&1
git pull --ff-only
if errorlevel 1 (
  echo   NOTE: fast-forward pull failed.
  echo   NOTE: setting the code to exactly match GitHub ^(local commits, if any, are dropped^).
  git reset --hard origin/main
)
git log --oneline -1

REM Build stamp = current git commit; the app shows it in Profile.
REM So "I rebuilt and nothing changed" can never again be confused
REM with "the phone still runs an old build".
for /f %%i in ('git rev-parse --short HEAD') do set COMMIT=%%i
if "%COMMIT%"=="" set COMMIT=none

echo.
echo [2/4] flutter clean + pub get
call flutter clean >nul
call flutter pub get

echo.
echo [3/4] Building release APK (this takes a few minutes)...
set ARGS=--release --split-per-abi --dart-define=API_BASE_URL=http://78.17.156.139:3000/app-api
set ARGS=%ARGS% --dart-define=BUILD_COMMIT=%COMMIT%
if not "%OWNER%"=="" set ARGS=%ARGS% --dart-define=OWNER_CODE=%OWNER%
call flutter build apk %ARGS%
if errorlevel 1 (
  echo.
  echo [ERROR] Build failed. Send the text above to the assistant.
  exit /b 1
)

echo.
echo [4/4] DONE
echo   APK folder: build\app\outputs\flutter-apk\
dir /b build\app\outputs\flutter-apk\*.apk
echo.
echo Install on phone (USB cable, USB debugging on):
echo   adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo.
endlocal
