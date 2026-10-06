# ============================================================
#  MOROK VPN — сборка APK.  Запуск в терминале Android Studio:
#      .\build.ps1              # релиз (для раздачи людям)
#      .\build.ps1 -Debug       # отладка на эмуляторе
#      .\build.ps1 -WithOwner   # релиз с владелец-кодом (только для себя)
# ============================================================
param(
    [switch]$Debug,
    [switch]$WithOwner,
    # Живой бэкенд. morokvpn.com не используем: домен припаркован регистратором
    # (verification-hold → A = 127.0.0.1), см. docs/RISK_ASSESSMENT_RF.md §9.
    [string]$Api = "http://78.17.156.139:3000/app-api",
    # Код владельца подставляется ТОЛЬКО при -WithOwner. В публичную сборку не попадает.
    [string]$OwnerCode = ""
)

$ErrorActionPreference = "Stop"
Write-Host ""
Write-Host "=== MOROK VPN ===" -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter не найден в PATH. Запускай этот скрипт из терминала Android Studio." -ForegroundColor Red
    exit 1
}

# 0. Свежий код с GitHub
Write-Host "`n[0/4] git pull" -ForegroundColor Yellow
try { git pull --ff-only 2>&1 | Write-Host } catch { Write-Host "  git pull пропущен ($_. )" -ForegroundColor DarkGray }

$buildArgs = @("build", "apk")

if ($Debug) {
    Write-Host "`n[1/4] Debug-сборка (эмулятор → 10.0.2.2)" -ForegroundColor Green
    $Api = "http://10.0.2.2:3000/app-api"
    $buildArgs += "--debug"
} else {
    Write-Host "`n[1/4] Release-сборка (--split-per-abi)" -ForegroundColor Cyan
    $buildArgs += @("--release", "--split-per-abi")
    if ($WithOwner) {
        if ([string]::IsNullOrWhiteSpace($OwnerCode)) {
            Write-Host "  -WithOwner без -OwnerCode: код не передан." -ForegroundColor Yellow
            Write-Host '  Пример: .\build.ps1 -WithOwner -OwnerCode "MOROK-XXXX-XXXX-XXXX-XXXX"' -ForegroundColor Yellow
            exit 1
        }
        Write-Host "  ВНИМАНИЕ: в эту сборку вшит владелец-код." -ForegroundColor Yellow
        $buildArgs += "--dart-define=OWNER_CODE=$OwnerCode"
    }
}

$buildArgs += "--dart-define=API_BASE_URL=$Api"
Write-Host "  API: $Api" -ForegroundColor DarkGray

Write-Host "`n[2/4] flutter clean + pub get" -ForegroundColor Yellow
flutter clean | Out-Null
flutter pub get | Out-Null

Write-Host "`n[3/4] flutter $($buildArgs -join ' ')" -ForegroundColor Yellow
& flutter @buildArgs
$code = $LASTEXITCODE

Write-Host "`n[4/4] Результат" -ForegroundColor Yellow
if ($code -ne 0) {
    Write-Host "СБОРКА УПАЛА — смотри текст выше." -ForegroundColor Red
    exit $code
}

$dir = "build\app\outputs\flutter-apk"
$want = if ($Debug) { "app-debug.apk" } else { "app-arm64-v8a-release.apk" }
$apk = Join-Path $dir $want

if (-not (Test-Path $apk)) { $apk = Get-ChildItem $dir -Filter *.apk | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName }

Write-Host "`n  Готово. Все APK лежат в $dir\" -ForegroundColor Green
if (Test-Path $apk) {
    Write-Host "  Ставить на телефон: $([IO.Path]::GetFileName($apk))  ($([math]::Round((Get-Item $apk).Length / 1MB, 1)) МБ)" -ForegroundColor Cyan
}
Write-Host "`n  Установка на телефон (USB, включённая отладка):" -ForegroundColor DarkGray
Write-Host "    adb install -r $apk" -ForegroundColor White
Write-Host ""
