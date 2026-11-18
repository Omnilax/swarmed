#!/bin/bash
# Builds the Swarmed Design Bible PDFs (see README.md). Two passes: render with hidden page markers,
# read where each heading landed, render again with page numbers; then join the volumes.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
export WIKI_WORK=${WIKI_WORK:-$(dirname "$GAME")/swarmed-wiki}
mkdir -p "$WIKI_WORK/build" "$WIKI_WORK/pdf" "$WIKI_WORK/shots"
cd "$HERE"
rm -f "$WIKI_WORK/build/pages.json"
MARK=1 python3 gen.py >/dev/null
node render.js "$WIKI_WORK/build" "$WIKI_WORK/pdf" >/dev/null
python3 pages.py "$WIKI_WORK"
python3 gen.py >/dev/null
node render.js "$WIKI_WORK/build" "$WIKI_WORK/pdf"
python3 merge.py "$WIKI_WORK"
