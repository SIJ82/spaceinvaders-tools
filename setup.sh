#!/usr/bin/env bash
# Setup per il progetto Space Invaders (Programmazione A.A. 2026/27) su Linux e macOS.
# Scarica il template del progetto nella cartella indicata, se è vuota, e lancia check.sh, che controlla
# gli strumenti (se mancano propone di installarli) e prova a compilare.
# Uso: bash <(curl -fsSL https://github.com/SIJ82/spaceinvaders-tools/releases/latest/download/setup.sh) [cartella]
# (default: spaceinvaders)

REPO="SIJ82/spaceinvaders-tools"

set -u

die() { printf '\033[31mErrore:\033[0m %s\n' "$1" >&2; exit 1; }

dir=${1:-spaceinvaders}
[[ -z $(ls -A "$dir" 2>/dev/null) ]] || die "la cartella $dir non è vuota: indicane un'altra, ad esempio bash setup.sh progetto"
mkdir -p "$dir" || exit 1

# template.tar.gz accanto allo script (test, creato da release.sh) o dall'ultima release
tgz=$(dirname "$0")/template.tar.gz
if [[ -f $tgz ]]; then
    tar -xzf "$tgz" -C "$dir"
else
    curl -fsSL "https://github.com/$REPO/releases/latest/download/template.tar.gz" | tar -xz -C "$dir"
fi || die "download del template non riuscito."

echo "Creato il progetto in $dir, controllo gli strumenti e provo a compilarlo:"
bash "$dir/check.sh" || exit 1
echo "Fatto. Apri la cartella $dir con VS Code: Ctrl+Shift+B compila, il task \"esegui\" lancia il gioco."
