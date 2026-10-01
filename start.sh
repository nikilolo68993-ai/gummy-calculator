#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
GUMMY_FLUTTER_CMD="${GUMMY_FLUTTER:-flutter}"
case "$(uname -s)" in
  Darwin) GUMMY_DEVICE=macos ;;
  Linux) GUMMY_DEVICE=linux ;;
  *) echo 'Use Start-Windows.cmd on Windows.'; exit 1 ;;
esac
"$GUMMY_FLUTTER_CMD" pub get
"$GUMMY_FLUTTER_CMD" run -d "$GUMMY_DEVICE"
