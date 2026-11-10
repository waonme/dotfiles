@echo off
rem dotfiles setup: double-click this file to run setup.ps1.
rem Right-click > "Run as administrator" to also apply admin-only settings (CapsLock -> Ctrl).
setlocal
set "PS=powershell"
where pwsh >nul 2>&1 && set "PS=pwsh"
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -KeepOpen
if errorlevel 1 pause
