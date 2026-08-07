#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: scripts/verify_app.sh /path/to/Barista.app}"
EXPECTED_VERSION="${BARISTA_EXPECTED_VERSION:-}"
EXPECTED_BUILD="${BARISTA_EXPECTED_BUILD:-}"
RESOURCE_BUNDLE="$APP_PATH/Contents/Resources/Barista_BaristaApp.bundle"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -x "$APP_PATH/Contents/MacOS/Barista" ]]; then
  echo "Missing Barista executable in $APP_PATH" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing resource bundle: $RESOURCE_BUNDLE" >&2
  exit 1
fi

resources=(
  "CaffeineCrystals_Fibrous_10xDarkField.jpg"
  "GitHub-Mark.png"
)
for resource in "${resources[@]}"; do
  if [[ ! -f "$RESOURCE_BUNDLE/$resource" ]]; then
    echo "Missing packaged resource: $RESOURCE_BUNDLE/$resource" >&2
    exit 1
  fi
done

if [[ -e "$APP_PATH/Barista_BaristaApp.bundle" ]]; then
  echo "Resource bundle must not be placed at the app root" >&2
  exit 1
fi

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null

if [[ -n "$EXPECTED_VERSION" ]]; then
  ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
  if [[ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "Expected version $EXPECTED_VERSION, found $ACTUAL_VERSION" >&2
    exit 1
  fi
fi

if [[ -n "$EXPECTED_BUILD" ]]; then
  ACTUAL_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
  if [[ "$ACTUAL_BUILD" != "$EXPECTED_BUILD" ]]; then
    echo "Expected build $EXPECTED_BUILD, found $ACTUAL_BUILD" >&2
    exit 1
  fi
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

SIGNING_DETAILS=$(/usr/bin/codesign -dvv "$APP_PATH" 2>&1)
if [[ "$SIGNING_DETAILS" != *"Signature=adhoc"* ]]; then
  echo "Expected an ad-hoc signature" >&2
  exit 1
fi
if [[ "$SIGNING_DETAILS" != *"Identifier=com.mdsakalu.barista"* ]]; then
  echo "Unexpected signing identifier" >&2
  exit 1
fi

echo "Verified app bundle: $APP_PATH"
