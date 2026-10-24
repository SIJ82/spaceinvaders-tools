#!/usr/bin/env bash
# Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su macOS.
# Controlla i Command Line Tools di Xcode (compilatore, make, ncurses) e CMake (con Homebrew):
# se mancano propone di installarli, poi crea lo scheletro del progetto nella cartella indicata,
# se è vuota, e prova a compilarlo.
# Uso: ./setup-macos.sh [cartella]   (default: spaceinvaders)

VERSION="0.1.0"
REPO="SIJ82/spaceinvaders-tools"
SCRIPT="setup-macos.sh"

set -u

ok()   { printf '  \033[32m[ok]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[manca]\033[0m %s\n' "$1"; }
die()  { printf '\033[31mErrore:\033[0m %s\n' "$1" >&2; exit 1; }
ask()  { local r; read -r -p "$1 [s/n] " r; [[ $r == [sSyY]* ]]; }

# --- aggiornamenti ---------------------------------------------------------------
check_update() {
    command -v curl >/dev/null || { echo "curl non trovato: salto il controllo aggiornamenti."; return; }
    local latest
    latest=$(curl -fsSL --max-time 5 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null |
        sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p')
    if [[ -z $latest ]]; then
        echo "Impossibile controllare gli aggiornamenti: continuo."
    elif [[ $latest != "$VERSION" ]]; then
        echo "È disponibile la versione $latest di questo script (tu hai la $VERSION)."
        if ask "Scaricarla e usarla al posto di questa?"; then
            local self tmp
            self=$(readlink -f "$0")
            tmp=$(mktemp)
            curl -fsSL "https://github.com/$REPO/releases/latest/download/$SCRIPT" -o "$tmp" ||
                die "download non riuscito, scaricala a mano da https://github.com/$REPO/releases/latest"
            chmod +x "$tmp" && mv "$tmp" "$self" && exec "$self" "$@"
        fi
    fi
}

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
create_project() {
    local dir=$1
    mkdir -p "$dir/include" "$dir/src" "$dir/.vscode" || die "non riesco a creare $dir"

    cat > "$dir/CMakeLists.txt" <<'EOF'
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
EOF

    cat > "$dir/src/main.cpp" <<'EOF'
#include <curses.h>

int main() {
    initscr();
    printw("Tutto pronto! Premi un tasto per uscire.");
    refresh();
    getch();
    endwin();
    return 0;
}
EOF

    cat > "$dir/.gitignore" <<'EOF'
build/
EOF

    cat > "$dir/.vscode/tasks.json" <<'EOF'
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
EOF
}

# --- main ------------------------------------------------------------------------
check_update "$@"

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
