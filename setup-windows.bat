@echo off
rem Lancia setup-windows.ps1 (doppio click o da terminale: setup-windows.bat [cartella])
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
pause
