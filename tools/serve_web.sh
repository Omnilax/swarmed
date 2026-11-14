#!/usr/bin/env bash
# Serves the web build on your local network so a phone on the same Wi-Fi can play it.
# Run tools/build_web.sh first. Then open the printed address on the phone.
set -euo pipefail
WEB="$(cd "$(dirname "$0")/../../web" && pwd)"
PORT="${PORT:-8000}"
IP="$( (ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}') | head -n1 )"
echo "On your phone (same Wi-Fi), open:  http://${IP:-<this computer's IP>}:$PORT"
echo "On this computer:                  http://localhost:$PORT"
cd "$WEB" && exec python3 -m http.server "$PORT"
