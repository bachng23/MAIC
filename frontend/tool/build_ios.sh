#!/usr/bin/env bash
# Regenerates iOS ephemeral Flutter artifacts and builds for device/simulator.
# Run from repo root on macOS: ./frontend/tool/build_ios.sh [--simulator]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

flutter pub get

if [[ "${1:-}" == "--simulator" ]]; then
  flutter build ios --simulator --no-codesign
else
  flutter build ios --no-codesign
fi
