# dotfiles setup script
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== dotfiles setup ===" -ForegroundColor Cyan

# 1. Install Scoop if not present
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "Scoop is already installed." -ForegroundColor Green
}

# 2. Import Scoop packages
$scoopfile = Join-Path $PSScriptRoot "scoopfile.json"
if (Test-Path $scoopfile) {
    Write-Host "Importing Scoop packages from scoopfile.json..." -ForegroundColor Yellow
    scoop import $scoopfile
} else {
    Write-Host "scoopfile.json not found, skipping." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Cyan
Write-Host "Installed packages:"
scoop list
