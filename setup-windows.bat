@echo off
rem Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su Windows.
rem Scarica il template del progetto nella cartella indicata, se e' vuota, e lancia check.bat, che controlla
rem gli strumenti (MSYS2, g++, cmake, PDCurses: se mancano propone di installarli) e prova a compilare.
rem Uso: doppio click, o da terminale setup-windows.bat [cartella]   (default: spaceinvaders)
setlocal
set DIR=%~1
if "%DIR%"=="" set DIR=spaceinvaders
set TAR=%SystemRoot%\System32\tar.exe

dir /b /a "%DIR%" 2>nul | findstr "^" >nul && (
    echo Errore: la cartella %DIR% non e' vuota: indicane un'altra, ad esempio setup-windows.bat progetto
    pause
    exit /b 1
)
mkdir "%DIR%" 2>nul

rem template.tar.gz accanto allo script (test, creato da release.sh) o dall'ultima release
if exist "%~dp0template.tar.gz" (
    "%TAR%" -xzf "%~dp0template.tar.gz" -C "%DIR%"
) else (
    "%SystemRoot%\System32\curl.exe" -fsSL -o "%TEMP%\template.tar.gz" https://github.com/SIJ82/spaceinvaders-tools/releases/latest/download/template.tar.gz && "%TAR%" -xzf "%TEMP%\template.tar.gz" -C "%DIR%"
)
if errorlevel 1 (
    echo Errore: download del template non riuscito.
    pause
    exit /b 1
)

echo Creato il progetto in %DIR%, controllo gli strumenti e provo a compilarlo:
call "%DIR%\check.bat"
if not errorlevel 1 echo Fatto. Apri la cartella %DIR% con VS Code: Ctrl+Shift+B compila, il task "esegui" lancia il gioco.
pause
