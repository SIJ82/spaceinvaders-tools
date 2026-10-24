#!/usr/bin/env bash
# Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su Linux.
# Controlla compilatore, CMake, make e ncurses (se mancano propone di installarli),
# poi crea il progetto dal template nella cartella indicata, se è vuota, e prova a compilarlo.
# Uso: bash <(curl -fsSL https://github.com/SIJ82/spaceinvaders-tools/releases/latest/download/setup-linux.sh) [cartella]
# (default: spaceinvaders). Lanciato così è sempre l'ultima versione.

VERSION="0.1.0"
REPO="SIJ82/spaceinvaders-tools"

set -u

ok()   { printf '  \033[32m[ok]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[manca]\033[0m %s\n' "$1"; }
die()  { printf '\033[31mErrore:\033[0m %s\n' "$1" >&2; exit 1; }
ask()  { local r; read -r -p "$1 [s/n] " r; [[ $r == [sSyY]* ]]; }

# --- strumenti -------------------------------------------------------------------
CURSES_TEST='#include <curses.h>
int main() { initscr(); endwin(); return 0; }'

check_tools() {
    local missing=0
    if command -v g++ >/dev/null; then ok "g++ $(g++ -dumpversion)"; else fail "g++"; missing=1; fi
    if command -v cmake >/dev/null; then
        ok "$(cmake --version | head -n1)"
    else
        fail "cmake"; missing=1
    fi
    if command -v make >/dev/null; then ok "make"; else fail "make"; missing=1; fi
    # serve per scaricare il template
    if command -v curl >/dev/null; then ok "curl"; else fail "curl"; missing=1; fi
    # ncurses: si prova a compilare e linkare un programma minimo
    if command -v g++ >/dev/null && echo "$CURSES_TEST" | g++ -x c++ - -o /dev/null -lncurses 2>/dev/null; then
        ok "ncurses"
    else
        fail "ncurses (libreria di sviluppo)"; missing=1
    fi
    return $missing
}

install_tools() {
    local cmd sudo=""
    [[ $EUID -ne 0 ]] && sudo="sudo"
    if command -v apt-get >/dev/null; then
        cmd="apt-get install -y g++ cmake make libncurses-dev curl"
    elif command -v dnf >/dev/null; then
        cmd="dnf install -y gcc-c++ cmake make ncurses-devel curl"
    elif command -v pacman >/dev/null; then
        cmd="pacman -S --needed --noconfirm gcc cmake make ncurses curl"
    elif command -v zypper >/dev/null; then
        cmd="zypper install -y gcc-c++ cmake make ncurses-devel curl"
    else
        die "distribuzione non riconosciuta: installa a mano g++, cmake, make, curl e la libreria di sviluppo di ncurses."
    fi
    echo "Comando di installazione: $sudo $cmd"
    ask "Lo eseguo?" || die "installa gli strumenti mancanti e rilancia lo script."
    if command -v apt-get >/dev/null; then $sudo apt-get update; fi
    $sudo $cmd || die "installazione non riuscita."
}

# --- progetto --------------------------------------------------------------------
# il template sta accanto allo script (clone del repo, test) o si scarica dall'archivio del tag di questa versione
create_project() {
    local dir=$1 src tmp
    src=$(dirname "$0")/template
    if [[ ! -d $src ]]; then
        tmp=$(mktemp -d)
        curl -fsSL "https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz" | tar -xz -C "$tmp" ||
            die "download del template non riuscito."
        src=$(echo "$tmp"/*/template)
    fi
    mkdir -p "$dir/include" && cp -R "$src/." "$dir" || die "non riesco a creare $dir"
}

# --- main ------------------------------------------------------------------------
echo "Controllo gli strumenti:"
if ! check_tools; then
    install_tools
    echo "Ricontrollo:"
    check_tools || die "manca ancora qualcosa, vedi sopra."
fi

DIR=${1:-spaceinvaders}
if [[ -e $DIR && -n $(ls -A "$DIR" 2>/dev/null) ]]; then
    echo "La cartella $DIR non è vuota: non creo niente."
    exit 0
fi
create_project "$DIR"
echo "Creato il progetto in $DIR, provo a compilarlo:"
if ! out=$(cd "$DIR" && cmake -S . -B build 2>&1 && cmake --build build 2>&1); then
    echo "$out"
    die "la compilazione di prova non è riuscita, vedi sopra."
fi
ok "compilazione di prova"
echo "Fatto. Apri la cartella $DIR con VS Code: Ctrl+Shift+B compila, il task \"esegui\" lancia il gioco."
