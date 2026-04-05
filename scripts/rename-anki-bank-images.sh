#!/usr/bin/env bash
# ABOUTME: Renames the 7 art images copied into the Anki image bank to their descriptive names.
# Run after dragging the Desktop screenshots into ~/Documents/Journal/anki/images/bank/.

set -e

BANK="$HOME/Documents/Journal/anki/images/bank"

# Map source screenshot names → descriptive bank names
declare -a PAIRS=(
  "Screenshot 2026-04-04 at 8.32.57 AM.png|rainbow-cloud-bank.png"
  "Screenshot 2026-04-04 at 8.33.19 AM.png|paint-stairs-bank.png"
  "Screenshot 2026-04-04 at 8.33.30 AM.png|sticker-apple-bank.png"
  "Screenshot 2026-04-04 at 8.34.29 AM.png|flower-gallery-bank.png"
  "Screenshot 2026-04-04 at 8.34.44 AM.png|butterfly-vase-bank.png"
  "Screenshot 2026-04-04 at 8.35.45 AM.png|blue-hands-bank.png"
  "Screenshot 2026-04-04 at 8.36.18 AM.png|green-hands-bank.png"
)

for pair in "${PAIRS[@]}"; do
  src="${pair%%|*}"
  dst="${pair##*|}"
  if [[ -f "$BANK/$src" ]]; then
    mv "$BANK/$src" "$BANK/$dst"
    sips --resampleWidth 800 "$BANK/$dst" > /dev/null 2>&1
    echo "✓ $dst"
  elif [[ -f "$BANK/$dst" ]]; then
    echo "already renamed: $dst"
  else
    echo "SKIP (not found): $src"
  fi
done

echo ""
echo "Bank contents:"
ls "$BANK"
