# Strumenti per il progetto Space Invaders su Linux: g++, cmake, make, curl (per gli aggiornamenti) e ncurses.
# Se mancano propone il comando del package manager e lo lancia con sudo solo dopo conferma.
# Lo legge check.sh (source) a ogni compilazione: usa ok, fail, die e ask di check.sh.

CURSES_TEST='#include <curses.h>
int main() { initscr(); endwin(); return 0; }'

# stampa i nomi di quello che manca
tools_missing() {
    command -v g++ >/dev/null || echo " g++"
    command -v cmake >/dev/null || echo " cmake"
    command -v make >/dev/null || echo " make"
    command -v curl >/dev/null || echo " curl"
    # ncurses: si prova a compilare e linkare un programma minimo
    command -v g++ >/dev/null && echo "$CURSES_TEST" | g++ -x c++ - -o /dev/null -lncurses 2>/dev/null ||
        echo " ncurses (libreria di sviluppo)"
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
    ask "Lo eseguo?" || die "installa gli strumenti mancanti e rilancia."
    if command -v apt-get >/dev/null; then $sudo apt-get update; fi
    $sudo $cmd || die "installazione non riuscita."
}

check_tools() {
    local missing
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
