@echo off
rem Back up this PC's per-machine files (e.g. .wslconfig) to the private dotfiles-hosts repo.
rem Double-click this file. It shows what changed and asks before committing and pushing.
rem No admin rights needed.
setlocal
set "PS=powershell"
where pwsh >nul 2>&1 && set "PS=pwsh"
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup-hosts.ps1"
echo.
pause
