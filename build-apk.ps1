# APK build script for Windows PowerShell
# Запуск: .\build-apk.ps1

param(
    [switch]$Release,
    [string]$ApiBaseUrl = "http://10.0.2.2:3000/api"
)

Write-Host "🔨 Сборка Morok VPN APK..." -ForegroundColor Cyan

# Проверка Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter не найден. Убедись что он в PATH." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Flutter версии $(flutter --version | Select-Object -First 1)" -ForegroundColor Green

# Очистка
Write-Host "`n🧹 Очистка..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Параметры сборки
$buildArgs = @()

if ($Release) {
    Write-Host "`n🔒 Release сборка (БЕЗ OWNER_CODE!)" -ForegroundColor Red
    Write-Host "⚠️  Владелец админки НЕ будет иметь доступа" -ForegroundColor Yellow
    
    $buildArgs += "build"
    $buildArgs += "apk"
    $buildArgs += "--release"
    $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
} else {
    Write-Host "`n🐛 Debug сборка (с OWNER_CODE)" -ForegroundColor Green
    Write-Host "🔑 Админ код: NEXA-66AB-AV3H-9HSJ-R8VZ" -ForegroundColor Cyan
    
    $buildArgs += "build"
    $buildArgs += "apk"
    $buildArgs += "--debug"
    $buildArgs += "--dart-define=OWNER_CODE=NEXA-66AB-AV3H-9HSJ-R8VZ"
    $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

Write-Host "`n📱 Сборка APK..." -ForegroundColor Yellow
flutter @buildArgs

if ($LASTEXITCODE -eq 0) {
    $apkPath = if ($Release) {
        "build\app\outputs\flutter-apk\app-release.apk"
    } else {
        "build\app\outputs\flutter-apk\app-debug.apk"
    }
    
    Write-Host "`n✅ Сборка успешна!" -ForegroundColor Green
    Write-Host "📦 APK: $apkPath" -ForegroundColor Cyan
    
    if (Test-Path $apkPath) {
        Write-Host "📊 Размер: $([math]::Round((Get-Item $apkPath).Length / 1MB, 2)) MB" -ForegroundColor Cyan
    }
} else {
    Write-Host "`n❌ Ошибка сборки!" -ForegroundColor Red
    exit 1
}
