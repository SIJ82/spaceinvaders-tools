# Strumenti per il progetto Space Invaders su macOS: i Command Line Tools di Xcode (compilatore, make, ncurses)
# e CMake (con Homebrew, o se non funziona dal pacchetto di cmake.org). Se mancano propone di installarli.
# Lo legge check.sh (source) a ogni compilazione: usa ok, fail, die e ask di check.sh.

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

# stampa i nomi di quello che manca
tools_missing() {
    if has_clt; then
        command -v make >/dev/null || echo " make"
        echo "$CURSES_TEST" | g++ -x c++ - -o /dev/null -lncurses 2>/dev/null || echo " ncurses"
    else
        echo " Command-Line-Tools-di-Xcode"
    fi
    command -v cmake >/dev/null || echo " cmake"
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
    ask "Procedo?" || die "installa gli strumenti mancanti e rilancia."
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

check_tools() {
    local missing
    # cmake installato prima da questo script, in un terminale che non ha ancora letto ~/.zprofile
    find_brew
    [[ -d $CMAKE_APP ]] && PATH="$CMAKE_APP/Contents/bin:$PATH"
    missing=$(tools_missing | tr -d '\n')
    if [[ -n $missing ]]; then
        fail "strumenti:$missing"
        install_tools
        missing=$(tools_missing | tr -d '\n')
        [[ -z $missing ]] || die "manca ancora:$missing"
    fi
    ok "strumenti"
}

check_tools
