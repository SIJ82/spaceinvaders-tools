@echo off
rem Controllo e compilazione del progetto Space Invaders (Programmazione A.A. 2026/27) su Windows.
rem Aggiorna gli script se c'e' una versione nuova (qui e non in .scripts: cosi' si aggiornano anche se
rem .scripts non funziona), controlla gli strumenti con .scripts\tools-windows.ps1, poi lancia check.sh
rem con la bash di MSYS2 per il controllo del codice e la compilazione.
rem Uso: check.bat [--run]
setlocal
cd /d "%~dp0"
set REPO=SIJ82/spaceinvaders-tools
rem curl e tar di Windows con il percorso completo: nel PATH puo' esserci prima MSYS2
set CURL=%SystemRoot%\System32\curl.exe
set TAR=%SystemRoot%\System32\tar.exe

rem --- aggiornamenti: ultima versione dal redirect di releases/latest, stampata solo se piu' recente di .scripts\VERSION
set LATEST=
for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "try { $l = curl.exe -fsI --max-time 5 https://github.com/%REPO%/releases/latest | Select-String '^location:'; $v = ($l -replace '.*/tag/v?', '').Trim(); $c = '0.0'; if (Test-Path .scripts\VERSION) { $c = (Get-Content .scripts\VERSION).Trim() }; if ([version]$v -gt [version]$c) { $v } } catch {}"`) do set LATEST=%%v
if not defined LATEST goto tools
echo Aggiorno gli script alla versione %LATEST%.
set NEW=%TEMP%\spaceinvaders-update
rd /s /q "%NEW%" 2>nul
mkdir "%NEW%"
"%CURL%" -fsSL -o "%NEW%\template.tar.gz" https://github.com/%REPO%/releases/latest/download/template.tar.gz && "%TAR%" -xzf "%NEW%\template.tar.gz" -C "%NEW%"
if errorlevel 1 (
    echo Aggiornamento non riuscito: continuo con questa versione.
    goto tools
)
call :update CMakeLists.txt "%NEW%\CMakeLists.txt" .scripts\orig\CMakeLists.txt
call :update .vscode\tasks.json "%NEW%\.vscode\tasks.json" .scripts\orig\tasks.json
rd /s /q .scripts 2>nul
xcopy /e /i /h /q "%NEW%\.scripts" .scripts >nul
copy /y "%NEW%\check.sh" . >nul
rem cmd legge il .bat una riga alla volta: la copia e il rilancio devono stare sulla stessa riga
copy /y "%NEW%\check.bat" "%~f0" >nul & "%~f0" %*

:tools
if not exist .scripts\tools-windows.ps1 (
    echo Manca la cartella .scripts: riscarica il progetto con setup-windows.bat.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File .scripts\tools-windows.ps1
if errorlevel 1 exit /b 1

rem UCRT64: nel PATH ci sono g++, cmake e ninja; CHERE_INVOKING: la shell di login resta in questa cartella
set MSYSTEM=UCRT64
set CHERE_INVOKING=1
C:\msys64\usr\bin\bash.exe -l check.sh %*
exit /b %errorlevel%

rem CMakeLists.txt e tasks.json (%1): si sostituiscono con la versione nuova (%2) da soli se sono ancora quelli
rem del template (%3, la copia originale in .scripts\orig), altrimenti si chiede; la versione dello studente resta in .bak
:update
fc /b %1 %2 >nul 2>&1 && exit /b
if not exist %1 goto replace
fc /b %1 %3 >nul 2>&1 && goto replace
set ANS=n
set /p ANS=C'e' una versione nuova di %~1, ma l'hai modificato: la uso (la tua resta in %~1.bak)? [s/n]
if /i not "%ANS:~0,1%"=="s" exit /b
copy /y %1 "%~1.bak" >nul
:replace
if not exist "%~dp1" mkdir "%~dp1"
copy /y %2 %1 >nul
echo   [ok] %~1 aggiornato
exit /b
