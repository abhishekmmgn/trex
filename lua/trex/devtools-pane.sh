#!/bin/sh
# The DevTools Pane's command (see devtools.lua):
#
#   devtools-pane.sh KB PORT INSPECTOR_URL SOCKET PROFILE REX SESSION BROWSER_BLOCK
#
# Runs kb on the Browser kb's DevTools origin with its own control socket and
# Chrome profile, so `kb list`, `kb ctl` and `kb mcp` don't see it. In the
# background it turns DevTools' screencast preview off, then opens the inspector,
# so DevTools paints without the preview from the start.
#
# It also closes this pane when the Browser Pane closes: Rex's config Lua can't
# react to a block closing, so a `rex wait` on the Browser Pane does it.
#
# DevTools keeps its settings in localStorage of the origin it is served from,
# http://127.0.0.1:PORT, and the port changes with every Browser kb run, so the
# setting is written each time. The key is `screencast-enabled` (Chrome 158).

kb=$1 port=$2 inspector=$3 socket=$4 profile=$5 rex=$6 session=$7 browser=$8
origin=http://127.0.0.1:$port

export KB_SOCKET="$socket" KB_CHROME_ARGS="--user-data-dir=$profile"

chrome_running() { /usr/bin/pgrep -f -- "--user-data-dir=$profile( |\$)" >/dev/null 2>&1; }

# The profile directory marks this Browser kb's DevTools Pane as taken. If another
# pane holds it, leave its socket and profile alone; take over only a stale one.
mkdir -p "$(dirname "$profile")"
if ! mkdir "$profile" 2>/dev/null; then
  if "$kb" ctl status >/dev/null 2>&1 || chrome_running; then
    echo "trex: this Browser Pane already has a DevTools Pane." >&2
    exit 1
  fi
fi

# kb's Chrome keeps writing to its profile for a moment after kb has gone, so
# wait (up to 5 s) for it to exit before removing the profile.
cleanup() {
  # Stop the watcher first, so it can't close a pane after this one is gone.
  if [ -n "$watcher" ]; then
    kids=$(/usr/bin/pgrep -P "$watcher")
    kill -9 "$watcher" 2>/dev/null
    [ -n "$kids" ] && kill $kids 2>/dev/null
    watcher=
  fi
  rm -f "$socket"
  n=0
  while [ "$n" -lt 50 ] && chrome_running; do
    sleep 0.1
    n=$((n + 1))
  done
  case $profile in */trex-devtools/?*) rm -rf "$profile" ;; esac
}
watcher=
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 143' TERM

(
  # kb answers on its socket a second or few after it starts. Only write the
  # setting once the page is on the DevTools origin.
  i=0
  while [ "$i" -lt 80 ]; do
    shown=$("$kb" ctl eval "localStorage.setItem('screencast-enabled','false'); location.origin" 2>/dev/null)
    if [ "$shown" = "$origin" ]; then
      exec "$kb" ctl open "$inspector"
    fi
    sleep 0.25
    i=$((i + 1))
  done
) </dev/null >/dev/null 2>&1 &

# `rex wait` returns when the Browser Pane's kb exits or its block closes, either
# way the Browser Pane is gone. REX_BLOCK is this pane, set by Rex.
if [ -x "$rex" ] && [ -n "$session" ] && [ -n "$browser" ] && [ -n "${REX_BLOCK:-}" ]; then
  (
    "$rex" wait -s "$session" "$browser" >/dev/null 2>&1
    "$rex" block close -s "$session" "$REX_BLOCK" >/dev/null 2>&1
  ) </dev/null &
  watcher=$!
fi

"$kb" "$origin/json/version"
status=$?
cleanup
exit "$status"
