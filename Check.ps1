# ==============================================================
#  Nexa VPN - check that the update was really applied
# ==============================================================
#
#  Run from the project root:
#     powershell -ExecutionPolicy Bypass -File .\Check.ps1

Write-Host ""
Write-Host "=== Checking your project files ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path .\pubspec.yaml)) {
    Write-Host "Wrong folder. Go to the project root (where pubspec.yaml is)." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

$okCount = 0
$badCount = 0

function Check($name, $condition, $badHint) {
    if ($condition) {
        Write-Host "  [OK]   $name" -ForegroundColor Green
        $script:okCount++
    } else {
        Write-Host "  [OLD]  $name" -ForegroundColor Red
        Write-Host "         $badHint" -ForegroundColor Gray
        $script:badCount++
    }
}

# NOTE: variable names here must NOT be $home / $host / $pwd / $error -
# those are reserved by PowerShell and cannot be assigned.

# 1. Turkey block removed from home screen
$homeFile = ".\lib\screens\home\home_screen.dart"
$homeText = if (Test-Path $homeFile) { Get-Content $homeFile -Raw } else { "" }
Check "Turkey block removed from home screen" `
      (($homeText -ne "") -and ($homeText -notmatch "HomeConnectionCard")) `
      "home_screen.dart still contains HomeConnectionCard"

# 2. SOCKS hardening disabled (this is what broke the tunnel)
$tunFile = ".\lib\services\vpn\xray_tunnel_manager.dart"
$tunText = if (Test-Path $tunFile) { Get-Content $tunFile -Raw } else { "" }
Check "SOCKS password removed (tunnel works)" `
      (($tunText -ne "") -and ($tunText -notmatch "XrayConfigHardener\(\)\.harden")) `
      "xray_tunnel_manager.dart still applies the password"

# 3. New identity files
Check "Device identity code present" `
      (Test-Path .\lib\services\identity\device_identity.dart) `
      "lib\services\identity\device_identity.dart is missing"

Check "Identity provider present" `
      (Test-Path .\lib\providers\identity_providers.dart) `
      "lib\providers\identity_providers.dart is missing"

Write-Host ""
if ($badCount -eq 0) {
    Write-Host "Sources are UP TO DATE ($okCount of $($okCount+$badCount))." -ForegroundColor Green
} else {
    Write-Host "$badCount file(s) are still OLD - unpack the archive again." -ForegroundColor Red
}

# --- where is the APK ----------------------------------------
Write-Host ""
Write-Host "=== APK search ===" -ForegroundColor Cyan
$apk = ".\build\app\outputs\flutter-apk\app-debug.apk"
if (Test-Path $apk) {
    $t = (Get-Item $apk).LastWriteTime
    Write-Host "  Built here: $t" -ForegroundColor Gray
} else {
    Write-Host "  No APK in this folder - it was never built here." -ForegroundColor Yellow
}

# Look for other copies of the project on disk - the phone may be
# running a build from a different folder.
Write-Host ""
Write-Host "Other Nexa project folders on disk:" -ForegroundColor Cyan
$roots = @("C:\Users\Hrowulf\StudioProjects", "C:\Users\Hrowulf\Downloads", "C:\Users\Hrowulf\Desktop")
foreach ($r in $roots) {
    if (Test-Path $r) {
        Get-ChildItem $r -Filter pubspec.yaml -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            ForEach-Object {
                $dir = $_.Directory.FullName
                $a = Join-Path $dir "build\app\outputs\flutter-apk\app-debug.apk"
                if (Test-Path $a) {
                    Write-Host "  $dir" -ForegroundColor White
                    Write-Host "     APK built: $((Get-Item $a).LastWriteTime)" -ForegroundColor Yellow
                } else {
                    Write-Host "  $dir  (no APK)" -ForegroundColor Gray
                }
            }
    }
}

Write-Host ""
Write-Host "---------------------------------------------" -ForegroundColor Green
Write-Host " Next: build from THIS folder and reinstall." -ForegroundColor Green
Write-Host ""
Write-Host "   flutter clean" -ForegroundColor White
Write-Host "   flutter pub get" -ForegroundColor White
Write-Host "   powershell -ExecutionPolicy Bypass -File .\BuildApp.ps1" -ForegroundColor White
Write-Host ""
Write-Host " DELETE the old app from the phone first." -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Green

Write-Host ""
Read-Host "Press Enter to close"
