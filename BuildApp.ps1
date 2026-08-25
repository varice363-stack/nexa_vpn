# ==============================================================
#  Nexa VPN - build Android app
#  (ASCII only: no encoding problems)
# ==============================================================
#
#  Run in a SECOND terminal tab, while the backend is running.
#
#     powershell -ExecutionPolicy Bypass -File .\BuildApp.ps1
#
#  Result:  build\app\outputs\flutter-apk\app-debug.apk

$ErrorActionPreference = "Stop"

# --- LAN address of this computer ----------------------------
# The phone talks to the backend using this address.
# If the app cannot reach the server, check "ipconfig" and fix it here.
$LanIp = "192.168.0.9"

function Fail($text, $hint) {
    Write-Host ""
    Write-Host "ERROR: $text" -ForegroundColor Red
    if ($hint) { Write-Host ""; Write-Host $hint -ForegroundColor Yellow }
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

if (-not (Test-Path .\pubspec.yaml)) {
    Fail "Wrong folder." "Go to the project root (where pubspec.yaml is)."
}

try { $null = & flutter --version } catch {
    Fail "Flutter not found." "Make sure Flutter is installed and added to PATH."
}

Write-Host ""
Write-Host "Backend address for the phone: http://${LanIp}:3000/api" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Cleaning previous build..." -ForegroundColor Cyan
& flutter clean

Write-Host ""
Write-Host "[2] Getting packages..." -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get failed." $null }

Write-Host ""
Write-Host "[3] Building APK (5-10 min on first run)..." -ForegroundColor Cyan
& flutter build apk --debug --dart-define=API_BASE_URL="http://${LanIp}:3000/api"
if ($LASTEXITCODE -ne 0) { Fail "APK build failed." "Please send me the full error text." }

$apk = ".\build\app\outputs\flutter-apk\app-debug.apk"

Write-Host ""
if (Test-Path $apk) {
    $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)
    Write-Host "---------------------------------------------" -ForegroundColor Green
    Write-Host " DONE. APK is ready:" -ForegroundColor Green
    Write-Host "   $apk  ($size MB)" -ForegroundColor White
    Write-Host ""
    Write-Host " Copy it to your phone and install." -ForegroundColor Green
    Write-Host "---------------------------------------------" -ForegroundColor Green
} else {
    Fail "APK not found where expected." $null
}

Write-Host ""
Read-Host "Press Enter to close"
