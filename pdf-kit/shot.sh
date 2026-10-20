#!/usr/bin/env bash
# Render individual .page divs to PNG so you can LOOK at them before shipping.
#   ./shot.sh labs-1-3.html            # every page
#   ./shot.sh labs-1-3.html 4 6 9      # only these pages
#
# Measuring proves a page FITS. Only looking proves it READS correctly.
set -euo pipefail

SRC="${1:?usage: ./shot.sh <input.html> [page numbers...]}"; shift

CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
[ -x "$CHROME" ] || CHROME="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
[ -x "$CHROME" ] || { echo "No Chrome or Edge found." >&2; exit 1; }

WIN_TMP="$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r\n')" || true
if [ -n "${WIN_TMP:-}" ] && [ "${WIN_TMP#\%}" = "$WIN_TMP" ]; then
  STAGE="$(wslpath -u "$WIN_TMP" 2>/dev/null)/pdfkit-shots"
fi
if [ -z "${STAGE:-}" ] || [ ! -d "$(dirname "$STAGE")" ]; then
  for d in /mnt/c/Users/*/AppData/Local/Temp; do
    case "$d" in *Public*|*Default*|*"All Users"*) continue;; esac
    [ -d "$d" ] && { STAGE="$d/pdfkit-shots"; break; }
  done
fi
mkdir -p "$STAGE"

PAGES=("$@")
if [ ${#PAGES[@]} -eq 0 ]; then
  TOTAL=$(grep -c 'class="page' "$SRC")
  PAGES=($(seq 1 "$TOTAL"))
fi

OUT="./shots"; mkdir -p "$OUT"
for N in "${PAGES[@]}"; do
  # IMPORTANT: hide the OTHERS. Never force display:block on the target --
  # that overrides flex/grid layouts (the cover page uses flex) and you will
  # "find" bugs that exist only in the screenshot.
  python3 -I -c "
import sys
src, stage, n = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src, encoding='utf-8').read()
css = '<style>.page:not(:nth-of-type(%s)){display:none!important}</style>' % n
open(stage + '/s' + n + '.html', 'w', encoding='utf-8').write(s.replace('</head>', css + '</head>'))
" "$SRC" "$STAGE" "$N"

  IN=$(wslpath -w "$STAGE/s$N.html"); IN="file:///${IN//\\//}"
  "$CHROME" --headless --disable-gpu --window-size=794,1123 \
            --screenshot="$(wslpath -w "$STAGE/s$N.png")" "$IN" 2>/dev/null || true
  sleep 1
  [ -f "$STAGE/s$N.png" ] && cp "$STAGE/s$N.png" "$OUT/page-$N.png" && echo "  ✓ $OUT/page-$N.png"
done
rm -rf "$STAGE"
echo "Now OPEN these images and read them. Measuring is not reviewing."
