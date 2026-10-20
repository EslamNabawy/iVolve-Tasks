#!/usr/bin/env bash
# Render a study-guide HTML file to PDF using Windows Chrome via WSL interop.
#   usage: ./build.sh labs-4-6.html "iVolve-Labs-4-6-StudyGuide.pdf"
# No pandoc / wkhtmltopdf / LaTeX needed — Chrome does the pagination.
set -euo pipefail

SRC="${1:?usage: ./build.sh <input.html> [output.pdf]}"
OUT_NAME="${2:-$(basename "${SRC%.html}").pdf}"

CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
[ -x "$CHROME" ] || CHROME="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
[ -x "$CHROME" ] || { echo "No Chrome or Edge found on the Windows side." >&2; exit 1; }

# Chrome is a Windows process: it cannot read /home/... , so stage under /mnt/c.
# Resolve the Windows TEMP dir, with fallbacks (cmd.exe is the most reliable probe).
WIN_TMP="$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r\n')" || true
if [ -n "${WIN_TMP:-}" ] && [ "${WIN_TMP#\%}" = "$WIN_TMP" ]; then
  STAGE="$(wslpath -u "$WIN_TMP" 2>/dev/null)/pdfkit"
fi
# Fallback: first real user profile under /mnt/c/Users
if [ -z "${STAGE:-}" ] || [ ! -d "$(dirname "$STAGE")" ]; then
  for d in /mnt/c/Users/*/AppData/Local/Temp; do
    case "$d" in *Public*|*Default*|*"All Users"*) continue;; esac
    [ -d "$d" ] && { STAGE="$d/pdfkit"; break; }
  done
fi
[ -n "${STAGE:-}" ] || { echo "Cannot find a writable Windows temp dir under /mnt/c." >&2; exit 1; }

mkdir -p "$STAGE"
cp "$SRC" "$STAGE/in.html"
echo "staging: $STAGE"

WIN_IN=$(wslpath -w "$STAGE/in.html"); WIN_IN="file:///${WIN_IN//\\//}"
WIN_OUT=$(wslpath -w "$STAGE/out.pdf")

"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
          --print-to-pdf="$WIN_OUT" "$WIN_IN" 2>&1 | grep -v 'ERROR:chrome' || true
sleep 3

[ -f "$STAGE/out.pdf" ] || { echo "Render failed — no PDF produced." >&2; exit 1; }
cp "$STAGE/out.pdf" "./$OUT_NAME"
rm -rf "$STAGE"

PAGES=$(python3 -I -c "import re,sys;d=open('$OUT_NAME','rb').read();print(len(re.findall(rb'/Type\s*/Page[^s]',d)))")
DIVS=$(grep -c 'class="page' "$SRC")
echo "✓ $OUT_NAME — ${PAGES} PDF pages from ${DIVS} page divs"
[ "$PAGES" = "$DIVS" ] || echo "⚠  MISMATCH: content is overflowing. Run measure.py and trim before shipping."
