#!/usr/bin/env bash
# ABOUTME: One-time script to copy initial art images from Desktop into the Anki image bank.
# Run from a terminal that has Desktop & Documents folder access.

set -e

BANK="$HOME/Documents/Journal/anki/images/bank"
DESK="$HOME/Desktop"

declare -A FILES=(
  ["Screenshot 2026-04-04 at 8.32.57 AM.png"]="rainbow-cloud-bank.png"
  ["Screenshot 2026-04-04 at 8.33.19 AM.png"]="paint-stairs-bank.png"
  ["Screenshot 2026-04-04 at 8.33.30 AM.png"]="sticker-apple-bank.png"
  ["Screenshot 2026-04-04 at 8.34.29 AM.png"]="flower-gallery-bank.png"
  ["Screenshot 2026-04-04 at 8.34.44 AM.png"]="butterfly-vase-bank.png"
  ["Screenshot 2026-04-04 at 8.35.45 AM.png"]="blue-hands-bank.png"
  ["Screenshot 2026-04-04 at 8.36.18 AM.png"]="green-hands-bank.png"
)

mkdir -p "$BANK"

for src_name in "${!FILES[@]}"; do
  dst_name="${FILES[$src_name]}"
  src="$DESK/$src_name"
  dst="$BANK/$dst_name"

  if [[ ! -f "$src" ]]; then
    echo "SKIP (not found): $src_name"
    continue
  fi

  cp "$src" "$dst"
  sips --resampleWidth 800 "$dst" > /dev/null 2>&1
  echo "✓ $dst_name"
done

echo ""
echo "Bank contents:"
ls "$BANK"
