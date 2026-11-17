#!/bin/bash
# Builds docs/GT_App_Data_Feature_Map.pdf from docs/GT_App_Data_Feature_Map.md.
# Needs pandoc, python3 and Google Chrome. Run from anywhere:
#
#     ./docs/pdf/build.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
md="$repo/docs/GT_App_Data_Feature_Map.md"
pdf="$repo/docs/GT_App_Data_Feature_Map.pdf"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 "$here/build.py" "$md" "$tmp/map.html" "$repo/GeorgiaTechApp/Resources/Fonts"
"$chrome" --headless=new --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=5000 --print-to-pdf="$pdf" "file://$tmp/map.html" >/dev/null 2>&1

echo "Wrote $pdf"
