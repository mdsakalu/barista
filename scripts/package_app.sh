#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Barista"
BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
TEMPLATE_APP="$ROOT_DIR/dist/$APP_NAME.app"
OUT_DIR="${1:-$ROOT_DIR/build}"
OUT_APP="$OUT_DIR/$APP_NAME.app"
APP_VERSION="${BARISTA_VERSION:-}"
APP_BUILD="${BARISTA_BUILD:-}"

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
RESOURCE_DIR="$OUT_APP/Contents/Resources"
RESOURCE_BUNDLE="$RESOURCE_DIR/Barista_BaristaApp.bundle"

mkdir -p "$OUT_DIR"
rm -rf "$OUT_APP"
cp -R "$TEMPLATE_APP" "$OUT_APP"
mkdir -p "$OUT_APP/Contents/MacOS"
mkdir -p "$RESOURCE_DIR"
cp "$BIN_PATH" "$OUT_APP/Contents/MacOS/$APP_NAME"

if [[ -d "$BUNDLE_PATH" ]]; then
  /usr/bin/ditto "$BUNDLE_PATH" "$RESOURCE_BUNDLE"
else
  echo "Missing resource bundle: $BUNDLE_PATH" >&2
  exit 1
fi

if [[ -f "$ROOT_DIR/ATTRIBUTION.md" ]]; then
  cp "$ROOT_DIR/ATTRIBUTION.md" "$OUT_APP/Contents/Resources/ATTRIBUTION.md"
fi

if [[ -f "$ROOT_DIR/LICENSE" ]]; then
  cp "$ROOT_DIR/LICENSE" "$RESOURCE_DIR/LICENSE"
fi

INFO_PLIST="$OUT_APP/Contents/Info.plist"
if [[ -n "$APP_VERSION" ]]; then
  APP_VERSION="${APP_VERSION#v}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$INFO_PLIST"
fi
if [[ -n "$APP_BUILD" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD" "$INFO_PLIST"
fi

/usr/bin/codesign --force --sign - --timestamp=none "$OUT_APP"
BARISTA_EXPECTED_VERSION="$APP_VERSION" \
  BARISTA_EXPECTED_BUILD="$APP_BUILD" \
  "$ROOT_DIR/scripts/verify_app.sh" "$OUT_APP"

echo "App bundle ready: $OUT_APP"
