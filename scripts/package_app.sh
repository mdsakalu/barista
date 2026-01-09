#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Barista"
BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
TEMPLATE_APP="$ROOT_DIR/dist/$APP_NAME.app"
OUT_DIR="${1:-$ROOT_DIR/build}"
OUT_APP="$OUT_DIR/$APP_NAME.app"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "Missing build output: $BIN_PATH" >&2
  echo "Run: swift build -c release" >&2
  exit 1
fi

if [[ ! -d "$TEMPLATE_APP" ]]; then
  echo "Missing app template: $TEMPLATE_APP" >&2
  exit 1
fi

BUNDLE_PATH="$ROOT_DIR/.build/release/Barista_BaristaApp.bundle"

mkdir -p "$OUT_DIR"
rm -rf "$OUT_APP"
cp -R "$TEMPLATE_APP" "$OUT_APP"
mkdir -p "$OUT_APP/Contents/MacOS"
cp "$BIN_PATH" "$OUT_APP/Contents/MacOS/$APP_NAME"

# Copy resource bundle
if [[ -d "$BUNDLE_PATH" ]]; then
  cp -R "$BUNDLE_PATH" "$OUT_APP/Contents/Resources/"
fi

if [[ -f "$ROOT_DIR/ATTRIBUTION.md" ]]; then
  cp "$ROOT_DIR/ATTRIBUTION.md" "$OUT_APP/Contents/Resources/ATTRIBUTION.md"
fi

if [[ -f "$ROOT_DIR/LICENSE" ]]; then
  cp "$ROOT_DIR/LICENSE" "$OUT_APP/Contents/Resources/LICENSE"
fi

if [[ -x /usr/bin/codesign ]]; then
  /usr/bin/codesign --force --deep --sign - "$OUT_APP" >/dev/null 2>&1 || true
fi

echo "App bundle ready: $OUT_APP"
