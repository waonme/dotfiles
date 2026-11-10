@echo off
rem dotfiles setup: double-click this file to run setup.ps1 (no admin rights needed).
rem Only if you also want admin-only settings (CapsLock -> Ctrl): right-click > "Run as administrator".
setlocal
set "PS=powershell"
where pwsh >nul 2>&1 && set "PS=pwsh"
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -KeepOpen
if errorlevel 1 pause
