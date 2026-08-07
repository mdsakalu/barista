#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"
swift build -c release
"$ROOT_DIR/scripts/package_app.sh" "$ROOT_DIR/build"
