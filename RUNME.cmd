@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUNME.ps1" %*
exit /b %ERRORLEVEL%
