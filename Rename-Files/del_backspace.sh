#!/bin/bash

# Basisverzeichnis, in dem die Dateien durchsucht werden sollen
basisverzeichnis="/home/arthur/Produktfotos SO26/Produktfotos SO26/Shopbilder 2026"

# Durchsuche alle Verzeichnisse und Dateien
find "$basisverzeichnis" -type f | while read -r file; do
  # Extrahiere den Dateinamen ohne Verzeichnis
  dateiname=$(basename "$file")

  # Entferne führende und nachfolgende Leerzeichen aus dem Dateinamen
  neuer_name=$(echo "$dateiname" | sed 's/^[ \t]*//;s/[ \t]*$//')

  # Wenn der neue Name sich vom alten unterscheidet, benenne die Datei um
  if [[ "$dateiname" != "$neuer_name" ]]; then
    verzeichnis=$(dirname "$file")
    mv "$file" "$verzeichnis/$neuer_name"
    echo "Datei umbenannt: $file -> $verzeichnis/$neuer_name"
  fi
done

echo "Leerzeichen in Dateinamen wurden entfernt."
