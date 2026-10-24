#!/usr/bin/env bash
# Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su macOS.
# Controlla i Command Line Tools di Xcode (compilatore, make, ncurses) e CMake (con Homebrew):
# se mancano propone di installarli, poi crea il progetto dal template nella cartella indicata,
# se è vuota, e prova a compilarlo.
# Uso: bash <(curl -fsSL https://github.com/SIJ82/spaceinvaders-tools/releases/latest/download/setup-macos.sh) [cartella]
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

# senza i Command Line Tools g++ e make esistono lo stesso, ma lanciarli apre la finestra di installazione
has_clt() { xcode-select -p >/dev/null 2>&1; }

# Homebrew sta in /opt/homebrew (Apple Silicon) o in /usr/local (Intel); da un terminale nuovo può non essere nel PATH
find_brew() {
    command -v brew >/dev/null && return 0
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x $b ]]; then eval "$("$b" shellenv)"; return 0; fi
    done
    return 1
}

check_tools() {
    local missing=0
    # cmake installato prima da questo script, in un terminale che non ha ancora letto ~/.zprofile
    find_brew
    [[ -d $CMAKE_APP ]] && PATH="$CMAKE_APP/Contents/bin:$PATH"
    if has_clt; then
        ok "Command Line Tools di Xcode"
        ok "compilatore: $(g++ --version | head -n1)"
        if command -v make >/dev/null; then ok "make"; else fail "make"; missing=1; fi
        if echo "$CURSES_TEST" | g++ -x c++ - -o /dev/null -lncurses 2>/dev/null; then ok "ncurses"; else fail "ncurses"; missing=1; fi
    else
        fail "Command Line Tools di Xcode (compilatore, make, ncurses)"; missing=1
    fi
    if command -v cmake >/dev/null; then ok "$(cmake --version | head -n1)"; else fail "cmake"; missing=1; fi
    return $missing
}

# cmake con Homebrew (installato se manca)
install_cmake_brew() {
    if ! find_brew; then
        sudo -v || return 1
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
        find_brew || return 1
        # come suggerisce Homebrew: brew nel PATH dei terminali aperti da ora in poi
        if ! grep -qs "brew shellenv" ~/.zprofile; then
            echo "eval \"\$($(command -v brew) shellenv)\"" >> ~/.zprofile
            ok "Homebrew aggiunto al PATH in ~/.zprofile"
        fi
    fi
    brew install cmake
}

# se Homebrew non va (non supporta più i Mac Intel): pacchetto ufficiale di cmake.org, universal, senza sudo
CMAKE_APP=~/Applications/CMake.app
install_cmake_app() {
    local url tmp
    url=$(curl -fsSL https://api.github.com/repos/Kitware/CMake/releases/latest |
        sed -n 's/.*"browser_download_url": *"\([^"]*macos-universal\.tar\.gz\)".*/\1/p' | head -n1)
    [[ -n $url ]] || return 1
    tmp=$(mktemp -d)
    curl -fL "$url" | tar -xz -C "$tmp" || return 1
    mkdir -p ~/Applications && rm -rf "$CMAKE_APP" && mv "$tmp"/*/CMake.app "$CMAKE_APP" || return 1
    rm -rf "$tmp"
    echo "export PATH=\"$CMAKE_APP/Contents/bin:\$PATH\"" >> ~/.zprofile
    export PATH="$CMAKE_APP/Contents/bin:$PATH"
    ok "cmake installato in $CMAKE_APP e aggiunto al PATH in ~/.zprofile"
}

install_tools() {
    has_clt || echo "Installo i Command Line Tools di Xcode (si apre una finestra: scegli \"Installa\")."
    if ! command -v cmake >/dev/null; then
        find_brew || echo "Installo Homebrew (https://brew.sh): serve la password del tuo utente."
        echo "Installo cmake con Homebrew (se non funziona, lo scarico da cmake.org)."
    fi
    ask "Procedo?" || die "installa gli strumenti mancanti e rilancia lo script."

    if ! has_clt; then
        xcode-select --install
        echo "Aspetto che l'installazione dei Command Line Tools finisca..."
        until has_clt; do sleep 5; done
    fi
    if ! command -v cmake >/dev/null && ! install_cmake_brew; then
        echo "Homebrew non ha funzionato: scarico cmake da cmake.org."
        install_cmake_app || die "installazione di cmake non riuscita."
    fi
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
