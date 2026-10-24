# Strumenti per il progetto Space Invaders su Windows: MSYS2 e i pacchetti UCRT64 (g++, cmake con ninja, PDCurses).
# Se mancano propone di installarli; aggiunge C:\msys64\ucrt64\bin al PATH dell'utente.
# Lo lancia check.bat a ogni compilazione.

$MSYS = "C:\msys64"
$UCRT = "$MSYS\ucrt64\bin"
$PACKAGES = "mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-pdcurses"  # cmake si porta dietro ninja

$ProgressPreference = "SilentlyContinue"   # senza, Invoke-WebRequest è lentissimo
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ok($msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  [manca] $msg" -ForegroundColor Red }
function Die($msg)  { Write-Host "Errore: $msg" -ForegroundColor Red; exit 1 }
function Ask($msg)  { (Read-Host "$msg [s/n]") -match '^[sSyY]' }

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

# i nomi di quello che manca
function Get-Missing {
    if (-not (Test-Path "$MSYS\usr\bin\bash.exe")) { return @("MSYS2") }
    $missing = @()
    foreach ($t in "g++", "cmake", "ninja") { if (-not (Test-Path "$UCRT\$t.exe")) { $missing += $t } }
    if (-not (Test-Path "$MSYS\ucrt64\include\pdcurses\curses.h")) { $missing += "PDCurses" }
    return $missing
}

$missing = Get-Missing
if ($missing) {
    Fail "strumenti: $missing"
    $hasMsys = Test-Path "$MSYS\usr\bin\bash.exe"
    if (-not $hasMsys) { Write-Host "Installo MSYS2 in $MSYS (con winget se c'è, altrimenti scaricando l'installer)." }
    Write-Host "Aggiorno MSYS2 e installo: $PACKAGES"
    if (-not (Ask "Procedo?")) { Die "installa gli strumenti mancanti e rilancia." }
    if (-not $hasMsys) {
        Install-Msys2
        if (-not (Test-Path "$MSYS\usr\bin\bash.exe")) { Die "installazione di MSYS2 non riuscita." }
    }
    # il primo aggiornamento può chiudere la shell (aggiorna pacman stesso): per questo è ripetuto
    Msys "pacman -Syu --noconfirm"
    Msys "pacman -Syu --noconfirm"
    Msys "pacman -S --needed --noconfirm $PACKAGES"
    $missing = Get-Missing
    if ($missing) { Die "manca ancora: $missing" }
}
Ok "strumenti"

# g++ e cmake anche dai terminali aperti da ora in poi (VS Code compreso)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $UCRT) {
    [Environment]::SetEnvironmentVariable("Path", ((@($UCRT, $userPath) | Where-Object { $_ }) -join ';'), "User")
    Ok "$UCRT aggiunto al PATH (vale per i terminali aperti da ora in poi)"
}
