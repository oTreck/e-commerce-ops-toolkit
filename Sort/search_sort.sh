#!/bin/bash

basisverzeichnis="/home/otreck/WORK/Income/session/BilderordnerHW26Online/Bilderordner_kopie"

# Keine Fehler bei Verzeichnissen ohne JPG-Dateien
shopt -s nullglob
# Optional: auch .JPG verarbeiten
shopt -s nocaseglob

# Zielordner 1 bis 7 erstellen
for i in {1..8}; do
    mkdir -p "$basisverzeichnis/$i"
done

for dir in "$basisverzeichnis"/*/; do
    ordnername="${dir%/}"
    ordnername="${ordnername##*/}"

    # Zielordner nicht erneut bearbeiten
    if [[ "$ordnername" =~ ^[1-7]$ ]]; then
        continue
    fi

    echo "Verzeichnis: $dir wird bearbeitet..."

    for file in "$dir"*.jpg; do
        dateiname="${file##*/}"

        # A1 bis A7 unmittelbar vor .jpg erkennen
        if [[ "$dateiname" =~ _A([1-7])\.jpg$ ]]; then
            zielordner="${BASH_REMATCH[1]}"

            echo "Verschiebe: $dateiname -> Ordner $zielordner"
            mv -- "$file" "$basisverzeichnis/$zielordner/"
        else
            echo "Unbekannte Endung in Datei $file, Datei wird nicht verschoben."
        fi
    done
done

echo "Dateien wurden erfolgreich in die entsprechenden Ordner verschoben."