#!/bin/bash

# Basisverzeichnis setzen, von dem aus du starten willst
path="/home/otreck/WORK/Income/session/Bilderordner HW26 Online/Bilderordner HW26 kopie"

# Funktion zum Zählen der Dateien in jedem Verzeichnis
count_files_in_directory() {
    for dir in "$1"/*; do
        if [ -d "$dir" ]; then
            # Anzahl der Dateien im Verzeichnis zählen
            file_count=$(find "$dir" -maxdepth 1 -type f | wc -l)
            if [ $file_count == 8 ]; then
            echo "Verzeichnis: $dir hat $file_count Dateien"
            else
                 echo -e "\033[31mVerzeichnis: $dir hat $file_count Dateien\033[0m"
            fi
            # Rekursiv für Unterverzeichnisse aufrufen
            count_files_in_directory "$dir"
        fi
    done
}

# Starten der Zählung im Basisverzeichnis
count_files_in_directory "$path"

