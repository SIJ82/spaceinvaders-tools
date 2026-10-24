# Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su Windows.
# Controlla MSYS2 e i pacchetti UCRT64 (g++, cmake, make, PDCurses): se mancano propone di installarli,
# aggiunge C:\msys64\ucrt64\bin al PATH dell'utente, poi crea lo scheletro del progetto nella cartella
# indicata, se è vuota, e prova a compilarlo.
# Uso: setup-windows.bat [cartella]   (default: spaceinvaders)

param([string]$Dir = "spaceinvaders")

$VERSION = "0.1.0"
$REPO = "SIJ82/spaceinvaders-tools"
$SCRIPT = "setup-windows.ps1"

$MSYS = "C:\msys64"
$UCRT = "$MSYS\ucrt64\bin"
$PACKAGES = "mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-pdcurses"  # cmake si porta dietro ninja

$ProgressPreference = "SilentlyContinue"   # senza, Invoke-WebRequest è lentissimo
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ok($msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  [manca] $msg" -ForegroundColor Red }
function Die($msg)  { Write-Host "Errore: $msg" -ForegroundColor Red; exit 1 }
function Ask($msg)  { (Read-Host "$msg [s/n]") -match '^[sSyY]' }

# --- aggiornamenti ---------------------------------------------------------------
try {
    $latest = (Invoke-RestMethod "https://api.github.com/repos/$REPO/releases/latest" -TimeoutSec 5).tag_name -replace '^v', ''
} catch {
    $latest = $null
}
if (-not $latest) {
    Write-Host "Impossibile controllare gli aggiornamenti: continuo."
} elseif ($latest -ne $VERSION) {
    Write-Host "È disponibile la versione $latest di questo script (tu hai la $VERSION)."
    if (Ask "Scaricarla e usarla al posto di questa?") {
        try {
            Invoke-WebRequest "https://github.com/$REPO/releases/latest/download/$SCRIPT" -OutFile $PSCommandPath
        } catch {
            Die "download non riuscito, scaricala a mano da https://github.com/$REPO/releases/latest"
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath $Dir
        exit $LASTEXITCODE
    }
}

# --- MSYS2 -----------------------------------------------------------------------
function Install-Msys2 {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # solo la sorgente winget: con le versioni vecchie di winget la sorgente msstore può fallire
        winget install --id MSYS2.MSYS2 --exact --source winget --accept-source-agreements --accept-package-agreements
    }
    # senza winget, o se winget non ce l'ha fatta, si usa l'installer
    if (-not (Test-Path "$MSYS\usr\bin\bash.exe")) {
        $exe = "$env:TEMP\msys2-x86_64-latest.exe"
        Write-Host "Scarico l'installer di MSYS2..."
        Invoke-WebRequest "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe" -OutFile $exe
        & $exe in --confirm-command --accept-messages --root $MSYS | Out-Host
    }
}

# i comandi di pacman si lanciano nella shell di MSYS2
function Msys($cmd) {
    $env:MSYSTEM = "UCRT64"
    & "$MSYS\usr\bin\bash.exe" -lc $cmd | Out-Host
}

function Test-Tools {
    $missing = $false
    if (Test-Path "$MSYS\usr\bin\bash.exe") { Ok "MSYS2" } else { Fail "MSYS2"; return $false }
    foreach ($t in @(@("g++", "g++.exe"), @("cmake", "cmake.exe"), @("ninja", "ninja.exe"))) {
        if (Test-Path "$UCRT\$($t[1])") { Ok $t[0] } else { Fail $t[0]; $missing = $true }
    }
    if (Test-Path "$MSYS\ucrt64\include\pdcurses\curses.h") { Ok "PDCurses" } else { Fail "PDCurses"; $missing = $true }
    return -not $missing
}

Write-Host "Controllo gli strumenti:"
if (-not (Test-Tools)) {
    $hasMsys = Test-Path "$MSYS\usr\bin\bash.exe"
    if (-not $hasMsys) { Write-Host "Installo MSYS2 in $MSYS (con winget se c'è, altrimenti scaricando l'installer)." }
    Write-Host "Aggiorno MSYS2 e installo: $PACKAGES"
    if (-not (Ask "Procedo?")) { Die "installa gli strumenti mancanti e rilancia lo script." }
    if (-not $hasMsys) {
        Install-Msys2
        if (-not (Test-Path "$MSYS\usr\bin\bash.exe")) { Die "installazione di MSYS2 non riuscita." }
    }
    # il primo aggiornamento può chiudere la shell (aggiorna pacman stesso): per questo è ripetuto
    Msys "pacman -Syu --noconfirm"
    Msys "pacman -Syu --noconfirm"
    Msys "pacman -S --needed --noconfirm $PACKAGES"
    Write-Host "Ricontrollo:"
    if (-not (Test-Tools)) { Die "manca ancora qualcosa, vedi sopra." }
}

# --- PATH ------------------------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $UCRT) {
    [Environment]::SetEnvironmentVariable("Path", ((@($UCRT, $userPath) | Where-Object { $_ }) -join ';'), "User")
    Ok "$UCRT aggiunto al PATH (vale per i terminali aperti da ora in poi)"
} else {
    Ok "$UCRT è nel PATH"
}
$env:Path = "$UCRT;$env:Path"

# --- progetto --------------------------------------------------------------------
if ((Test-Path $Dir) -and (Get-ChildItem -Force $Dir | Select-Object -First 1)) {
    Write-Host "La cartella $Dir non è vuota: non creo niente."
    exit 0
}
New-Item -ItemType Directory -Force "$Dir\include", "$Dir\src", "$Dir\.vscode" | Out-Null

# file senza BOM e con a capo \n, uguali a quelli creati su Linux e macOS
function Write-File($path, $text) {
    [IO.File]::WriteAllText((Join-Path (Resolve-Path $Dir) $path), $text.Replace("`r`n", "`n"))
}

Write-File "CMakeLists.txt" @'
cmake_minimum_required(VERSION 3.16)
project(SpaceInvaders CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# tutti i .cpp in src/ (anche quelli aggiunti dopo), gli header in include/
file(GLOB SOURCES CONFIGURE_DEPENDS src/*.cpp)
add_executable(spaceinvaders ${SOURCES})
target_include_directories(spaceinvaders PRIVATE include)
target_compile_options(spaceinvaders PRIVATE -Wall -Wextra)

if(WIN32)
    # Windows (MSYS2 UCRT64): PDCurses
    find_path(CURSES_INCLUDE_DIR curses.h PATH_SUFFIXES pdcurses REQUIRED)
    # la versione per console (libpdcurses.a apre una finestra sua), statica: l'eseguibile parte senza DLL accanto
    find_library(CURSES_LIBRARY libpdcurses_wincon.a REQUIRED)
    target_include_directories(spaceinvaders PRIVATE ${CURSES_INCLUDE_DIR})
    # la PDCurses di MSYS2 è compilata in UTF-8: senza questa define non si linka
    target_compile_definitions(spaceinvaders PRIVATE PDC_FORCE_UTF8)
    # winmm: PDCurses la usa per beep()
    target_link_libraries(spaceinvaders PRIVATE ${CURSES_LIBRARY} winmm -static)
else()
    # Linux e macOS: ncurses
    find_package(Curses REQUIRED)
    target_include_directories(spaceinvaders PRIVATE ${CURSES_INCLUDE_DIRS})
    target_link_libraries(spaceinvaders PRIVATE ${CURSES_LIBRARIES})
endif()

'@

Write-File "src\main.cpp" @'
#include <curses.h>

int main() {
    initscr();
    printw("Tutto pronto! Premi un tasto per uscire.");
    refresh();
    getch();
    endwin();
    return 0;
}

'@

Write-File ".gitignore" @'
build/

'@

Write-File ".vscode\tasks.json" @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "configura",
            "type": "shell",
            "command": "cmake -S . -B build",
            "problemMatcher": []
        },
        {
            "label": "compila",
            "type": "shell",
            "command": "cmake --build build",
            "dependsOn": "configura",
            "group": { "kind": "build", "isDefault": true },
            "problemMatcher": "$gcc"
        },
        {
            "label": "esegui",
            "type": "shell",
            "command": "./spaceinvaders",
            "options": { "cwd": "${workspaceFolder}/build" },
            "dependsOn": "compila",
            "presentation": { "focus": true, "panel": "dedicated" },
            "problemMatcher": []
        }
    ]
}

'@

Write-Host "Creato il progetto in $Dir, provo a compilarlo:"
Push-Location $Dir
$out = cmake -S . -B build 2>&1
if ($LASTEXITCODE -eq 0) { $out = cmake --build build 2>&1 }
$built = $LASTEXITCODE -eq 0
Pop-Location
if (-not $built) { $out | Out-Host; Die "la compilazione di prova non è riuscita, vedi sopra." }
Ok "compilazione di prova"
Write-Host "Fatto. Apri la cartella $Dir con VS Code: Ctrl+Shift+B compila, il task `"esegui`" lancia il gioco."
