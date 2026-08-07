#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Barista"
BUNDLE_ID="com.mdsakalu.barista"
TRACKED_PID_KEY="barista.caffeinatePid"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

refuse_active_session() {
  local tracked_pid
  local tracked_command

  tracked_pid="$(/usr/bin/defaults read "$BUNDLE_ID" "$TRACKED_PID_KEY" 2>/dev/null || true)"
  if [[ ! "$tracked_pid" =~ ^[0-9]+$ ]]; then
    return
  fi

  tracked_command="$(/bin/ps -p "$tracked_pid" -o args= 2>/dev/null || true)"
  case "$tracked_command" in
    /usr/bin/caffeinate\ *|caffeinate\ *)
      echo "Barista has an active caffeinate session (PID $tracked_pid). Stop it before rebuilding." >&2
      exit 1
      ;;
  esac
}

stop_running_app() {
  local pid
  local command
  local contents_dir
  local bundle_id
  local plist

  while read -r pid; do
    [[ -n "$pid" ]] || continue
    command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
    case "$command" in
      */Contents/MacOS/Barista)
        contents_dir="${command%/MacOS/Barista}"
        plist="$contents_dir/Info.plist"
        [[ -f "$plist" ]] || continue
        bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)"
        if [[ "$bundle_id" == "$BUNDLE_ID" ]]; then
          /bin/kill -TERM "$pid"
        fi
        ;;
    esac
  done < <(/usr/bin/pgrep -x "$APP_NAME" || true)

  for _ in 1 2 3 4 5; do
    if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

refuse_active_session
stop_running_app
"$ROOT_DIR/scripts/build_app.sh"

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in 1 2 3 4 5; do
      if /usr/bin/pgrep -f "$APP_BINARY" >/dev/null 2>&1; then
        exit 0
      fi
      sleep 1
    done
    echo "Barista did not launch from $APP_BUNDLE" >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
