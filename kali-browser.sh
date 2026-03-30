#!/bin/bash
# Launch Chromium on Kali via X11 forwarding
# Works on WSL2 (WSLg) and macOS (XQuartz required)
#
# Usage: ./kali-browser.sh [URL]
# Example: ./kali-browser.sh http://10.0.1.20

cd "$(dirname "$0")"

URL="${1:-}"

if [ -z "$DISPLAY" ]; then
  echo "Error: No X server detected."
  echo "  WSL2: WSLg should set this automatically"
  echo "  macOS: Install XQuartz (https://www.xquartz.org/)"
  exit 1
fi

echo "Launching Chromium on Kali (X11 forwarding)..."
echo "Close the browser window or Ctrl+C to stop."

vagrant ssh kali -- -X \
  "chromium --no-sandbox --disable-gpu --disable-software-rasterizer --new-window --user-data-dir=/tmp/chromium-x11 --force-device-scale-factor=1.5 ${URL}" 2>/dev/null
