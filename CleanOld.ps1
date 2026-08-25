# ==============================================================
#  Nexa VPN - remove files deleted in this update
# ==============================================================
#
#  An archive can only add or replace files, never delete them.
#  These belong to the old account system and must go.
#
#     powershell -ExecutionPolicy Bypass -File .\CleanOld.ps1

$ErrorActionPreference = "Stop"

if (-not (Test-Path .\pubspec.yaml)) {
    Write-Host "Wrong folder. Go to the project root (pubspec.yaml)." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# lib\screens\auth  - login and registration screens
# test\auth_flow_test.dart - tests for those screens
$obsolete = @(
    ".\lib\screens\auth",
    ".\test\auth_flow_test.dart"
)

Write-Host ""
$removed = 0
foreach ($item in $obsolete) {
    if (Test-Path $item) {
        Remove-Item -Path $item -Recurse -Force
        Write-Host "  removed: $item" -ForegroundColor Yellow
        $removed++
    }
}

Write-Host ""
if ($removed -eq 0) {
    Write-Host "Nothing to remove - already clean." -ForegroundColor Green
} else {
    Write-Host "Removed: $removed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "   flutter clean"
Write-Host "   flutter pub get"
Write-Host "   powershell -ExecutionPolicy Bypass -File .\BuildApp.ps1"
Write-Host ""
Read-Host "Press Enter to close"
