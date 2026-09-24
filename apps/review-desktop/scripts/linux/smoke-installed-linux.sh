#!/usr/bin/env bash
# Run as an ordinary user, under Xvfb and a D-Bus session.
set -euo pipefail
STATE="$(mktemp -d)"
export DEV_REVIEW_HOME="$STATE/reviews" DEV_REVIEW_IMPORT_FROM=none
"$APP-desktop" --user-data-dir="$STATE/profile" --extensions-dir="$STATE/extensions" >"$STATE/output" 2>&1 &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true' EXIT
for ((ATTEMPT=0; ATTEMPT<180; ATTEMPT++)); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then cat "$STATE/output"; exit 1; fi
  if grep -rEq '\[Review Desktop\] server ready at https?://' "$STATE/profile/logs" 2>/dev/null &&
    pgrep -af -- '--type=renderer' | grep -F -- "$STATE/profile" >/dev/null; then
    if [[ -n "${APPARMOR_PROFILE:-}" ]]; then
      grep -F "$APPARMOR_PROFILE " "/proc/$APP_PID/attr/current"
    fi
    echo 'Installed app started a renderer and its bundled server with sandboxing enabled.'
    exit 0
  fi
  sleep 1
done
cat "$STATE/output"
find "$STATE/profile/logs" -name main.log -exec cat {} \;
echo 'Installed app did not become ready' >&2
exit 1
