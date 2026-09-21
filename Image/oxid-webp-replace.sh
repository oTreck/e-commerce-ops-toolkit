#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
    cat <<'EOF'
Verwendung:
  ./oxid-webp-replace.sh QUELLORDNER ZIELORDNER [QUALITAET]

Beispiel:
  ./oxid-webp-replace.sh ./originale ./out/pictures/generated 95

Aus:
  QUELLORDNER/produkte/soave_clog_filz_6758-76.jpg

wird:
  ZIELORDNER/produkte/soave_clog_filz_6758-76.jpg.webp

Vorhandene Zieldateien werden überschrieben. Die Originalbilder bleiben
unverändert. Unterstützt werden JPG, JPEG und PNG.
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage >&2
    exit 1
fi

source_dir=$1
target_dir=$2
quality=${3:-95}

if [[ ! -d "$source_dir" ]]; then
    printf 'Fehler: Quellordner nicht gefunden: %s\n' "$source_dir" >&2
    exit 1
fi

if [[ ! "$quality" =~ ^[0-9]+$ ]] || (( quality < 0 || quality > 100 )); then
    printf 'Fehler: Die Qualität muss zwischen 0 und 100 liegen.\n' >&2
    exit 1
fi

if ! command -v cwebp >/dev/null 2>&1; then
    printf 'Fehler: cwebp ist nicht installiert.\n' >&2
    printf 'Debian/Ubuntu: sudo apt install webp\n' >&2
    exit 1
fi

source_dir=$(cd "$source_dir" && pwd -P)
mkdir -p "$target_dir"
target_dir=$(cd "$target_dir" && pwd -P)

converted=0
failed=0

while IFS= read -r -d '' source_file; do
    relative_path=${source_file#"$source_dir"/}

    # OXID hängt .webp an den vollständigen Originalnamen an:
    # bild.jpg -> bild.jpg.webp
    target_file="$target_dir/$relative_path.webp"
    target_parent=${target_file%/*}
    mkdir -p "$target_parent"

    temporary_file=$(mktemp "$target_parent/.oxid-webp.XXXXXX")

    if cwebp \
        -quiet \
        -q "$quality" \
        -m 6 \
        -mt \
        -alpha_q 100 \
        "$source_file" \
        -o "$temporary_file"; then
        mv -f -- "$temporary_file" "$target_file"
        printf 'OK: %s\n' "$target_file"
        ((converted += 1))
    else
        rm -f -- "$temporary_file"
        printf 'FEHLER: %s\n' "$source_file" >&2
        ((failed += 1))
    fi
done < <(
    find "$source_dir" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
        -print0
)

printf '\nFertig: %d konvertiert, %d fehlgeschlagen.\n' "$converted" "$failed"

if (( failed > 0 )); then
    exit 2
fi
