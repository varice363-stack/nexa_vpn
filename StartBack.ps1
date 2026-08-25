# ==============================================================
#  Nexa VPN - start backend
#  (ASCII only: no encoding problems)
# ==============================================================
#
#  Installs dependencies, updates the database, seeds plans,
#  builds and starts the API server.
#
#  Usage from project root:
#     powershell -ExecutionPolicy Bypass -File .\StartBack.ps1

$ErrorActionPreference = "Stop"

function Fail($text, $hint) {
    Write-Host ""
    Write-Host "ERROR: $text" -ForegroundColor Red
    if ($hint) {
        Write-Host ""
        Write-Host $hint -ForegroundColor Yellow
    }
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

if (-not (Test-Path .\pubspec.yaml)) {
    Fail "Wrong folder." "Go to the project root (where pubspec.yaml is) and run again."
}

try { $null = & node --version } catch {
    Fail "Node.js not found." "Install Node.js LTS from https://nodejs.org/ then reopen the terminal."
}
Write-Host "Node.js: $(& node --version)" -ForegroundColor DarkGray

Set-Location .\backend

if (-not (Test-Path .\.env)) {
    Fail "Missing backend\.env" "Create it from the sample:   copy .env.example .env"
}

Write-Host ""
Write-Host "[1] Installing dependencies (1-2 min)..." -ForegroundColor Cyan
& npm install
if ($LASTEXITCODE -ne 0) { Fail "npm install failed." "Check your internet connection and retry." }

Write-Host ""
Write-Host "[2] Preparing database client..." -ForegroundColor Cyan
& npm run prisma:generate
if ($LASTEXITCODE -ne 0) { Fail "prisma generate failed." $null }

Write-Host ""
Write-Host "[3] Updating database structure..." -ForegroundColor Cyan
& npm run prisma:deploy
if ($LASTEXITCODE -ne 0) {
    Fail "Could not reach or update the database." @"
Two usual reasons:

 1) PostgreSQL is not installed or not running.
    Install it:  https://www.postgresql.org/download/windows/
    Then create the database:
       powershell -ExecutionPolicy Bypass -File ..\CreateDb.ps1

 2) Wrong DATABASE_URL in backend\.env
    Open it:  notepad backend\.env
"@
}

Write-Host ""
Write-Host "[4] Seeding plans and servers..." -ForegroundColor Cyan
& npm run prisma:seed
if ($LASTEXITCODE -ne 0) { Fail "Seeding failed." $null }

Write-Host ""
Write-Host "[5] Building..." -ForegroundColor Cyan
& npm run build
if ($LASTEXITCODE -ne 0) { Fail "Build failed." "Please send me the full error text." }

Write-Host ""
Write-Host "---------------------------------------------" -ForegroundColor Green
Write-Host " Starting the server." -ForegroundColor Green
Write-Host ""
Write-Host " Wait for this line:" -ForegroundColor Green
Write-Host "   Nexa VPN API ready" -ForegroundColor White
Write-Host ""
Write-Host " KEEP THIS WINDOW OPEN - the server runs here." -ForegroundColor Yellow
Write-Host " Open a SECOND terminal tab to build the app." -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Green
Write-Host ""

& npm run start
