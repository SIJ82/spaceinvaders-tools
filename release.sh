#!/usr/bin/env bash
# Crea template.tar.gz: il template, la cartella include/ e in .scripts/orig le copie originali di CMakeLists.txt
# e tasks.json (check.sh le aggiorna da sole solo se lo studente non le ha modificate).
# Con --publish crea anche la release vVERSION (da template/.scripts/VERSION) su GitHub.
# Uso: ./release.sh [--publish]

set -eu
cd "$(dirname "$0")"
version=$(cat template/.scripts/VERSION)
tmp=$(mktemp -d)
cp -R template/. "$tmp"
mkdir -p "$tmp/include" "$tmp/.scripts/orig"
cp template/CMakeLists.txt template/.vscode/tasks.json "$tmp/.scripts/orig/"
tar -czf template.tar.gz -C "$tmp" .
rm -rf "$tmp"
echo "template.tar.gz, versione $version"

if [[ ${1:-} == --publish ]]; then
    gh release create "v$version" setup.sh setup-windows.bat template.tar.gz --title "v$version" --notes "Versione $version"
fi
