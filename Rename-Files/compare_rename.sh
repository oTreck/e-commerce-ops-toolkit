#!/bin/bash

basisverzeichnis="/home/otreck/WORK/Income/session/BilderordnerHW26Online/Bilderordner_kopie"
namensliste="namen_liste.txt"

while IFS= read -r line; do
  bereinigt_line=$(echo "$line" | tr -d '\r')

  # Portable Regex ohne -P
  artikelnummer=$(echo "$bereinigt_line" | grep -Eo '[0-9]{4,}-[0-9]{2}')

  if [[ -z "$artikelnummer" ]]; then
    echo "Keine Artikelnummer gefunden in: $bereinigt_line"
    continue
  fi

  find "$basisverzeichnis" -type f -name "${artikelnummer}_*.jpg" -print0 |
  while IFS= read -r -d '' file; do
    ordner=$(dirname "$file")
    neuer_name="${ordner}/${bereinigt_line}.jpg"

    mv "$file" "$neuer_name"
    echo "Umbenannt: $file → $neuer_name"
  done

done < "$namensliste"

echo "Fertig."



./resize-images.sh  /home/otreck/WORK/Income/session/BilderordnerHW26Online/Bilderordner_kopie 1667x2500
Error: Base directory does not exist: /home/otreck/WORK/Income/session/Bilderordner
