#!/usr/bin/env bash
# Builds the browser version of Swarmed (love.js, LÖVE 11.4 compiled to WebAssembly).
#
#   tools/build_web.sh          -> ../web/ (open with tools/serve_web.sh), ../swarmed-web.zip
#                                  and ../swarmed.love (opens in the LÖVE app on Android)
#   tools/build_web.sh --serve  -> build, then serve it on your network for a phone to open
#
# Needs Node.js (npx downloads love.js the first time). The zip uploads as-is to itch.io
# ("HTML" project, "This file will be played in the browser").
set -euo pipefail
GAME="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(cd "$GAME/.." && pwd)/web"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

(cd "$GAME" && zip -9 -qr "$TMP/swarmed.love" . -x "tools/*" "docs/*" "*.md" ".git/*" ".gitignore")
rm -rf "$OUT"
npx --yes love.js@11.4.1 -c -t Swarmed -m 134217728 "$TMP/swarmed.love" "$OUT" >/dev/null
cp "$GAME/tools/web/index.html" "$OUT/index.html"
cp "$TMP/swarmed.love" "$OUT/../swarmed.love"      # same game for the LÖVE app (Android, desktop)
rm -rf "$OUT/theme"
(cd "$OUT" && rm -f ../swarmed-web.zip && zip -9 -qr ../swarmed-web.zip .)
echo "web build: $OUT  (zip: ${OUT%/web}/swarmed-web.zip)"

if [[ "${1:-}" == "--serve" ]]; then exec "$GAME/tools/serve_web.sh"; fi
