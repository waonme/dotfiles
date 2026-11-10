@echo off
rem dotfiles: double-click this file (no admin rights needed).
rem It opens menu.ps1: the status of this PC and a numbered menu (first-time setup, update, backup, CapsLock -> Ctrl).
rem To run setup without the menu: pwsh -ExecutionPolicy Bypass -File "%USERPROFILE%\dotfiles\setup.ps1" -KeepOpen
setlocal
set "PS=powershell"
where pwsh >nul 2>&1 && set "PS=pwsh"
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0menu.ps1"
if errorlevel 1 pause
