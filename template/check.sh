#!/usr/bin/env bash
# Controllo e compilazione del progetto Space Invaders (Programmazione A.A. 2026/27).
# Aggiorna gli script se c'è una versione nuova, controlla gli strumenti (e propone di installarli),
# verifica che il codice usi solo librerie e costrutti consentiti e sia organizzato come richiesto,
# poi compila con CMake. Con --run (o -r) lancia anche il gioco.
# Uso: bash check.sh [--run]   (su Windows: check.bat [--run], che fa aggiornamento e strumenti e poi lancia questo)

REPO="SIJ82/spaceinvaders-tools"

set -u

ok()   { printf '  \033[32m[ok]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[manca]\033[0m %s\n' "$1"; }
die()  { printf '\033[31mErrore:\033[0m %s\n' "$1" >&2; exit 1; }
ask()  { local r; read -r -p "$1 [s/n] " r && [[ $r == [sSyY]* ]]; }

# --- aggiornamenti ---------------------------------------------------------------
# vero se la versione $1 è più recente della $2 (sort -V non c'è su macOS)
newer() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        split(a, x, "."); split(b, y, ".")
        for (i = 1; i <= 3; i++) { if (x[i] + 0 != y[i] + 0) exit !(x[i] + 0 > y[i] + 0) }
        exit 1 }'
}

same() { [[ -f $1 && -f $2 && "$(<"$1")" == "$(<"$2")" ]]; }

# CMakeLists.txt e tasks.json: si sostituiscono da soli se sono ancora quelli del template ($3, la copia
# originale in .scripts/orig), altrimenti si chiede; la versione dello studente resta in .bak
update_file() {
    local f=$1 new=$2 orig=$3
    same "$f" "$new" && return
    if [[ ! -e $f ]] || same "$f" "$orig"; then
        mkdir -p "$(dirname "$f")" && cp "$new" "$f" && ok "$f aggiornato"
    elif ask "C'è una versione nuova di $f, ma l'hai modificato: la uso (la tua resta in $f.bak)?"; then
        cp "$f" "$f.bak" && cp "$new" "$f" && ok "$f aggiornato (la tua versione è in $f.bak)"
    fi
}

# l'ultima versione si legge dal redirect di releases/latest (l'API di GitHub ha un limite di richieste per IP,
# che un laboratorio intero dietro lo stesso indirizzo supera)
check_update() {
    command -v curl >/dev/null || return
    local latest current tmp
    latest=$(curl -fsI --max-time 5 "https://github.com/$REPO/releases/latest" 2>/dev/null |
        grep -i '^location:' | sed 's#.*/tag/v\{0,1\}##' | tr -d '\r\n')
    current=$(cat .scripts/VERSION 2>/dev/null || echo 0)
    # solo se quella pubblicata è più recente (non durante le prove di una versione nuova)
    [[ -n $latest ]] && newer "$latest" "$current" || return
    echo "Aggiorno gli script alla versione $latest (avevi la $current)."
    tmp=$(mktemp -d)
    if ! curl -fsSL "https://github.com/$REPO/releases/latest/download/template.tar.gz" | tar -xz -C "$tmp"; then
        rm -rf "$tmp"
        echo "Aggiornamento non riuscito: continuo con questa versione."
        return
    fi
    update_file CMakeLists.txt "$tmp/CMakeLists.txt" .scripts/orig/CMakeLists.txt
    update_file .vscode/tasks.json "$tmp/.vscode/tasks.json" .scripts/orig/tasks.json
    rm -rf .scripts && cp -R "$tmp/.scripts" . && cp "$tmp/check.sh" "$tmp/check.bat" .
    rm -rf "$tmp"
    exec bash check.sh "$@"
}

# --- codice ----------------------------------------------------------------------
check_sources() {
    local files all out f
    shopt -s nullglob
    files=(src/*.cpp include/*.hpp include/*.h)
    all=(src/* include/*)
    [[ ${#files[@]} -gt 0 ]] || die "nessun file .cpp in src/."
    out=$(
        # CMake compila solo src/*.cpp e cerca gli header in include/
        for f in src/*.hpp src/*.h include/*.cpp *.cpp *.hpp *.h; do
            echo "$f:1:1: error: $f è fuori posto (gli header vanno in include/, i .cpp in src/)"
        done
        awk -v files="${all[*]}" -f .scripts/rules.awk "${files[@]}"
    )
    shopt -u nullglob
    if [[ -n $out ]]; then
        echo "$out"
        echo
        echo "Problemi trovati:"
        echo "$out" | sed 's/.*error: /  /' | sort -u
        die "correggi e rilancia (vedi Requisiti tecnici nelle specifiche)."
    fi
    ok "librerie, costrutti e organizzazione del codice"
}

# --- main ------------------------------------------------------------------------
main() {
    local run=0 out
    case ${1:-} in
        "") ;;
        --run|-r) run=1 ;;
        *) die "uso: bash check.sh [--run]" ;;
    esac
    # su Windows (bash di MSYS2) aggiornamento e strumenti li ha già fatti check.bat
    if [[ -z ${MSYSTEM:-} ]]; then
        check_update "$@"
        [[ -f .scripts/VERSION ]] || die "manca la cartella .scripts: riscarica il progetto con lo script di setup."
        case $(uname) in
            Darwin) source .scripts/tools-macos.sh ;;
            *) source .scripts/tools-linux.sh ;;
        esac
    fi
    check_sources
    if ! out=$(cmake -S . -B build 2>&1); then
        echo "$out"
        die "configurazione con CMake non riuscita, vedi sopra."
    fi
    cmake --build build || die "compilazione non riuscita, vedi sopra."
    ok "compilazione"
    if [[ $run == 1 ]]; then
        cd build && ./spaceinvaders
    fi
}

# lo script si lancia dalla cartella del progetto, in cui si trova
cd "$(dirname "$0")" || exit 1
# tutto in main: se l'aggiornamento sostituisce il file, bash ha già letto lo script intero
main "$@"
exit
