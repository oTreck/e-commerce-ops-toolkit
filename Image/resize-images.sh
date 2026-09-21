#!/bin/bash

# ------------------------------------------------------------
# resize-images.sh
#
# Description:
#   Recursively resizes image files in a given directory to a
#   fixed resolution based on CLI arguments.
#
# Typical E-Commerce Use Cases:
#   - Normalizing product image dimensions
#   - Preparing images for shop imports
#   - Cleaning up inconsistent media libraries
#
# Platform:
#   - Linux only
#   - Tested on Debian
#
# Requirements:
#   - bash
#   - find (GNU findutils)
#   - ImageMagick (convert)
#
# Warning:
#   - This script overwrites image files.
#   - Always back up your data before running.
# ------------------------------------------------------------

# --------------------
# Argument handling
# --------------------

if [[ "$#" -lt 3 ]]; then
  echo "Usage:"
  echo "  $0 <BASE_DIR> <WIDTHxHEIGHT> <EXTENSION...>"
  echo
  echo "Example:"
  echo "  $0 ./images 443x665 jpg png"
  exit 1
fi

BASE_DIR="$1"
TARGET_RESOLUTION="$2"
shift 2
IMAGE_EXTENSIONS=("$@")

# --------------------
# Safety checks
# --------------------

if [[ ! -d "$BASE_DIR" ]]; then
  echo "Error: Base directory does not exist: $BASE_DIR"
  exit 1
fi

if ! [[ "$TARGET_RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "Error: Resolution must be in WIDTHxHEIGHT format (e.g. 443x665)"
  exit 1
fi

if ! command -v convert >/dev/null 2>&1; then
  echo "Error: ImageMagick is not installed (convert command missing)"
  exit 1
fi

# --------------------
# Processing
# --------------------

echo "Starting image resize process"
echo "Base directory      : $BASE_DIR"
echo "Target resolution   : $TARGET_RESOLUTION"
echo "File extensions     : ${IMAGE_EXTENSIONS[*]}"
echo "----------------------------------------"

for ext in "${IMAGE_EXTENSIONS[@]}"; do
  find "$BASE_DIR" -type f -iname "*.${ext}" | while read -r image; do
    convert "$image" -resize "${TARGET_RESOLUTION}!" "$image"
    echo "Resized: $image → $TARGET_RESOLUTION"
  done
done

echo "Image resize process completed."

