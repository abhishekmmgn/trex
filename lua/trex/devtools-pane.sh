#!/bin/sh
# The DevTools Pane's command (see devtools.lua), configured by environment:
#
#   TREX_KB         path of kb
#   TREX_PORT       the Browser Pane's kb's DevTools port
#   TREX_INSPECTOR  the inspector URL to show
#   TREX_SOCKET     this pane's kb control socket
#   TREX_PROFILE    this pane's Chrome profile directory
#   TREX_REX        path of the rex CLI
#   TREX_SESSION    the Rex session
#   TREX_WATCH      JSON for devtools-watch.lua
#
# Runs kb on the Browser Pane's kb's DevTools origin with its own control socket
# and Chrome profile, so `kb list`, `kb ctl` and `kb mcp` don't see it. In the
# background it turns DevTools' screencast preview off, then opens the inspector,
# so DevTools paints without the preview from the start.
#
# Beside it runs devtools-watch.lua, which closes this pane with its Browser
# Pane, remembers its side, and follows the page the Browser Pane shows.
#
# DevTools keeps its settings in localStorage of the origin it is served from,
# http://127.0.0.1:PORT, and the port changes with every Browser Pane kb run, so
# the setting is written each time. The key is `screencast-enabled` (Chrome 158).

kb=$TREX_KB socket=$TREX_SOCKET profile=$TREX_PROFILE rex=$TREX_REX
origin=http://127.0.0.1:$TREX_PORT

# This pane's own kb, never a Browser Pane's.
own_kb() { KB_SOCKET="$socket" KB_CHROME_ARGS="--user-data-dir=$profile" "$kb" "$@"; }

chrome_running() { /usr/bin/pgrep -f -- "--user-data-dir=$profile( |\$)" >/dev/null 2>&1; }

# The profile directory marks this Browser Pane's DevTools Pane as taken. If
# another pane holds it, leave its socket and profile alone; take over only a stale one.
mkdir -p "$(dirname "$profile")"
if ! mkdir "$profile" 2>/dev/null; then
  if own_kb ctl status >/dev/null 2>&1 || chrome_running; then
    echo "trex: this Browser Pane already has a DevTools Pane." >&2
    exit 1
  fi
fi

# kb's Chrome keeps writing to its profile for a moment after kb has gone, so
# wait (up to 5 s) for it to exit before removing the profile.
cleanup() {
  # Stop the watcher first, so it can't act on a pane that is gone.
  if [ -n "$watcher" ]; then
    kill "$watcher" 2>/dev/null
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
    shown=$(own_kb ctl eval "localStorage.setItem('screencast-enabled','false'); location.origin" 2>/dev/null)
    if [ "$shown" = "$origin" ]; then
      own_kb ctl open "$TREX_INSPECTOR"
      exit
    fi
    sleep 0.25
    i=$((i + 1))
  done
) </dev/null >/dev/null 2>&1 &

if [ -x "$rex" ] && [ -n "${TREX_SESSION:-}" ] && [ -n "${REX_BLOCK:-}" ]; then
  "$rex" do "$(dirname "$0")/devtools-watch.lua" -s "$TREX_SESSION" </dev/null >/dev/null 2>&1 &
  watcher=$!
fi

own_kb "$origin/json/version"
status=$?
cleanup
exit "$status"
