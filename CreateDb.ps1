# ==============================================================
#  Nexa VPN - database setup
#  (ASCII only: no encoding problems)
# ==============================================================
#
#  Run AFTER installing PostgreSQL.
#  Creates user "nexa" / password "nexa" and database "nexa_vpn"
#  exactly as written in backend\.env
#
#  Usage from project root:
#     powershell -ExecutionPolicy Bypass -File .\CreateDb.ps1

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== Nexa VPN: database setup ===" -ForegroundColor Cyan
Write-Host ""

# --- find psql.exe -------------------------------------------
$psql = $null
foreach ($v in @("18","17","16","15","14")) {
    $try = "C:\Program Files\PostgreSQL\$v\bin\psql.exe"
    if (Test-Path $try) { $psql = $try; break }
}
if (-not $psql) {
    $f = Get-ChildItem "C:\Program Files\PostgreSQL" -Recurse -Filter psql.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { $psql = $f.FullName }
}

if (-not $psql) {
    Write-Host "PostgreSQL NOT FOUND on this computer." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it from:" -ForegroundColor Yellow
    Write-Host "   https://www.postgresql.org/download/windows/"
    Write-Host ""
    Write-Host "In the installer: remember the 'postgres' password, keep port 5432." -ForegroundColor Yellow
    Write-Host "Then close this terminal, open a new one, run this script again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "Found PostgreSQL:" -ForegroundColor Green
Write-Host "   $psql" -ForegroundColor Gray
Write-Host ""

# --- service -------------------------------------------------
$svc = Get-Service | Where-Object { $_.Name -like "*postgre*" } | Select-Object -First 1
if ($svc) {
    if ($svc.Status -ne "Running") {
        Write-Host "Service $($svc.Name) is stopped. Starting..." -ForegroundColor Yellow
        Start-Service $svc.Name
        Start-Sleep -Seconds 3
    }
    Write-Host "Service $($svc.Name): $((Get-Service $svc.Name).Status)" -ForegroundColor Green
} else {
    Write-Host "No PostgreSQL service found - server may not be running." -ForegroundColor Yellow
}
Write-Host ""

# --- ask for postgres password -------------------------------
Write-Host "Enter the password for user 'postgres'" -ForegroundColor Cyan
Write-Host "(the one you typed during PostgreSQL installation)" -ForegroundColor Gray
$sec = Read-Host "Password" -AsSecureString
$b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($b)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)
$env:PGPASSWORD = $pass

# --- test connection -----------------------------------------
Write-Host ""
Write-Host "Testing connection..." -ForegroundColor Cyan
$check = & $psql -U postgres -h localhost -p 5432 -tAc "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Connection FAILED." -ForegroundColor Red
    Write-Host "Server said:" -ForegroundColor Red
    Write-Host "   $check" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usually this means a wrong password. Run the script again." -ForegroundColor Yellow
    $env:PGPASSWORD = ""
    Read-Host "Press Enter to close"
    exit 1
}
Write-Host "Connection OK." -ForegroundColor Green

# --- create role ---------------------------------------------
Write-Host ""
Write-Host "Creating user 'nexa'..." -ForegroundColor Cyan
$u = & $psql -U postgres -h localhost -tAc "SELECT 1 FROM pg_roles WHERE rolname='nexa';" 2>&1
if ("$u".Trim() -eq "1") {
    Write-Host "   already exists - resetting password" -ForegroundColor Gray
    & $psql -U postgres -h localhost -c "ALTER USER nexa WITH PASSWORD 'nexa' CREATEDB;" | Out-Null
} else {
    & $psql -U postgres -h localhost -c "CREATE USER nexa WITH PASSWORD 'nexa' CREATEDB;" | Out-Null
    Write-Host "   created" -ForegroundColor Green
}

# --- create database -----------------------------------------
Write-Host "Creating database 'nexa_vpn'..." -ForegroundColor Cyan
$d = & $psql -U postgres -h localhost -tAc "SELECT 1 FROM pg_database WHERE datname='nexa_vpn';" 2>&1
if ("$d".Trim() -eq "1") {
    Write-Host "   already exists - keeping it" -ForegroundColor Gray
} else {
    & $psql -U postgres -h localhost -c "CREATE DATABASE nexa_vpn OWNER nexa;" | Out-Null
    Write-Host "   created" -ForegroundColor Green
}

# --- verify as nexa ------------------------------------------
Write-Host ""
Write-Host "Verifying login as 'nexa'..." -ForegroundColor Cyan
$env:PGPASSWORD = "nexa"
$final = & $psql -U nexa -h localhost -d nexa_vpn -tAc "SELECT 'ok';" 2>&1
$env:PGPASSWORD = ""

Write-Host ""
if ("$final".Trim() -eq "ok") {
    Write-Host "---------------------------------------------" -ForegroundColor Green
    Write-Host " DONE. Database is ready." -ForegroundColor Green
    Write-Host ""
    Write-Host " Next step - start the backend:" -ForegroundColor Green
    Write-Host "   powershell -ExecutionPolicy Bypass -File .\StartBack.ps1" -ForegroundColor White
    Write-Host "---------------------------------------------" -ForegroundColor Green
} else {
    Write-Host "Database created, but login as 'nexa' failed." -ForegroundColor Red
    Write-Host "Output: $final" -ForegroundColor Gray
    Write-Host "Please send me this text." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to close"
