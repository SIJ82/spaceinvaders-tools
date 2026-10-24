#!/usr/bin/env bash
# Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su Linux.
# Controlla compilatore, CMake, make e ncurses (se mancano propone di installarli),
# poi crea lo scheletro del progetto nella cartella indicata, se è vuota, e prova a compilarlo.
# Uso: ./setup-linux.sh [cartella]   (default: spaceinvaders)

VERSION="0.1.0"
REPO="SIJ82/spaceinvaders-tools"
SCRIPT="setup-linux.sh"

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

check_tools() {
    local missing=0
    if command -v g++ >/dev/null; then ok "g++ $(g++ -dumpversion)"; else fail "g++"; missing=1; fi
    if command -v cmake >/dev/null; then
        ok "$(cmake --version | head -n1)"
    else
        fail "cmake"; missing=1
    fi
    if command -v make >/dev/null; then ok "make"; else fail "make"; missing=1; fi
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
        cmd="apt-get install -y g++ cmake make libncurses-dev"
    elif command -v dnf >/dev/null; then
        cmd="dnf install -y gcc-c++ cmake make ncurses-devel"
    elif command -v pacman >/dev/null; then
        cmd="pacman -S --needed --noconfirm gcc cmake make ncurses"
    elif command -v zypper >/dev/null; then
        cmd="zypper install -y gcc-c++ cmake make ncurses-devel"
    else
        die "distribuzione non riconosciuta: installa a mano g++, cmake, make e la libreria di sviluppo di ncurses."
    fi
    echo "Comando di installazione: $sudo $cmd"
    ask "Lo eseguo?" || die "installa gli strumenti mancanti e rilancia lo script."
    if command -v apt-get >/dev/null; then $sudo apt-get update; fi
    $sudo $cmd || die "installazione non riuscita."
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
