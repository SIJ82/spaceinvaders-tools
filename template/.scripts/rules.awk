# Regole del progetto, le applica check.sh: awk -v files="file del progetto" -f rules.awk file...
# Toglie commenti e contenuto di stringhe e caratteri, poi cerca in ogni riga:
# #include <...> fuori dall'elenco, nomi della libreria standard vietati, auto, template e lambda.
# Controlla anche che #include "..." scriva il nome del file con le stesse maiuscole e che ogni
# classe X stia in include/X.hpp con il suo src/X.cpp.
# Stampa "file:riga:1: error: ..." (formato di gcc, così VS Code li mostra fra i problemi).
function err(msg) { printf "%s:%d:1: error: %s\n", FILENAME, FNR, msg }
function word(s, w) { return s ~ ("(^|[^A-Za-z0-9_])" w "([^A-Za-z0-9_]|$)") }
BEGIN {
    split("curses.h ctime chrono iostream fstream cstring cstdlib random cmath cstdio", a)
    for (i in a) okinc[a[i]] = 1
    # vietati comunque compaiano (anche se arrivano da altri header, come std::string da iostream)
    split("string wstring thread mutex to_string stoi stol stof stod auto template", a)
    for (i in a) words[a[i]] = 1
    # contenitori: vietati con std:: o come template (vector<int>)
    split("vector list map set multimap multiset unordered_map unordered_set deque stack queue priority_queue array pair tuple", a)
    for (i in a) cont[a[i]] = 1
    # funzioni di algorithm e simili: vietate con std:: (senza potrebbero essere funzioni vostre)
    split("sort min max swap find reverse fill copy count getline", a)
    for (i in a) funcs[a[i]] = 1
    # file del progetto: per nome esatto e per nome in minuscolo
    n = split(files, a)
    for (i = 1; i <= n; i++) {
        exists[a[i]] = 1
        b = a[i]; sub(/.*\//, "", b); base[b] = 1; lower[tolower(b)] = b
    }
}
FNR == 1 { incomment = 0 }
{
    # #include "...": prima di togliere le stringhe
    if (!incomment && $0 ~ /^[ \t]*#[ \t]*include[ \t]*"/) {
        h = $0; sub(/^[^"]*"/, "", h); sub(/".*/, "", h); sub(/.*\//, "", h)
        if (!(h in base) && (tolower(h) in lower))
            err("#include \"" h "\": il file si chiama " lower[tolower(h)] " (maiuscole e minuscole devono coincidere)")
        next
    }
    line = $0; out = ""; n = length(line); i = 1
    while (i <= n) {
        c = substr(line, i, 1); c2 = substr(line, i, 2)
        if (incomment) { if (c2 == "*/") { incomment = 0; i += 2 } else i++; continue }
        if (c2 == "//") break
        if (c2 == "/*") { incomment = 1; i += 2; continue }
        if (c == "\"" || c == "\047") {
            out = out c; i++
            while (i <= n && substr(line, i, 1) != c) { if (substr(line, i, 1) == "\\") i++; i++ }
            out = out c; i++; continue
        }
        out = out c; i++
    }
    if (out ~ /^[ \t]*#[ \t]*include[ \t]*</) {
        h = out; sub(/^[^<]*</, "", h); sub(/>.*/, "", h)
        if (!(h in okinc)) err("#include <" h "> non consentito")
        next
    }
    for (w in words) if (word(out, w)) err((w == "auto" || w == "template" ? w : "std::" w) " non consentito")
    for (w in cont) if (out ~ ("(^|[^A-Za-z0-9_])" w "[ \t]*<") || out ~ ("std::" w "([^A-Za-z0-9_]|$)")) err("std::" w " non consentito")
    for (w in funcs) if (out ~ ("std::" w "([^A-Za-z0-9_]|$)")) err("std::" w " non consentito")
    # lambda: [...] dopo = ( , { ; o return, seguita da ( o {  (un indice di array segue un nome, ] o ))
    if (out ~ /(^|[=(,{;]|return)[ \t]*\[[^]]*\][ \t]*[({]/) err("lambda non consentita")
    # definizione di classe (non "class X;", "enum class X" o il parametro di un template)
    if (match(out, /(^|[^A-Za-z0-9_])class[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        pre = substr(out, 1, RSTART); rest = substr(out, RSTART + RLENGTH)
        name = substr(out, RSTART, RLENGTH); sub(/.*class[ \t]+/, "", name)
        if (pre !~ /enum[ \t]*$/ && pre !~ /[<,][ \t]*$/ && rest !~ /^[ \t]*;/) {
            if (FILENAME != "include/" name ".hpp")
                err("la classe " name " va definita in include/" name ".hpp")
            else if (!(("src/" name ".cpp") in exists))
                err("la classe " name " non ha il suo src/" name ".cpp")
        }
    }
}
