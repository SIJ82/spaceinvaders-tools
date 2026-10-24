@echo off
rem Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su Windows.
rem Scarica setup-windows.ps1 accanto a se' (solo la prima volta: poi si aggiorna da solo) e lo lancia.
rem Uso: doppio click, o da terminale setup-windows.bat [cartella]
if not exist "%~dp0setup-windows.ps1" (
    echo Scarico setup-windows.ps1...
    "%SystemRoot%\System32\curl.exe" -fsSL -o "%~dp0setup-windows.ps1" https://github.com/SIJ82/spaceinvaders-tools/releases/latest/download/setup-windows.ps1
    if errorlevel 1 (
        del "%~dp0setup-windows.ps1" 2>nul
        echo Download non riuscito: controlla la connessione e riprova.
        pause
        exit /b 1
    )
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
pause
