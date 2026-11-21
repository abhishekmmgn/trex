#!/bin/sh
# Waits for the pick in a Browser Pane's page, then copies its description to
# the clipboard. pick.lua starts it in the background once pick.js has turned
# pick mode on; it ends when the user picks, cancels, or the page goes away.
#
#   pick-wait.sh KB KB_ID CLIPBOARD
#
# KB is the kb binary, KB_ID the Browser Pane's kb ("N-xxxx"), CLIPBOARD a
# command that reads the text to copy on stdin (/usr/bin/pbcopy).
#
# Each wait asks the page for at most 25 s, because kb gives up on a request
# after 30 s (REQUEST_TIMEOUT in its src/devtools.rs). A wait that fails anyway
# is retried while pick mode is still on; once the page is gone or pick mode is
# off, this exits. The page ends pick mode itself if no wait comes for 90 s.

kb=$1 id=$2 clipboard=$3

# Never with a DevTools Pane's KB_SOCKET, which beats -i.
unset KB_SOCKET KB_INSTANCE
# Rex runs this with no locale, and pbcopy then reads its input as Mac Roman
# (× arrives as √ó). The description is UTF-8.
export LC_CTYPE=UTF-8

ctl() { "$kb" ctl -i "$id" "$@"; }

while :; do
  if ! out=$(ctl eval 'globalThis.__trexPick ? globalThis.__trexPick.wait(25000) : "gone"' 2>/dev/null); then
    on=$(ctl eval 'globalThis.__trexPick?.active() ? "on" : "off"' 2>/dev/null) || exit 0
    [ "$on" = on ] || exit 0
    continue
  fi
  case $out in
    pending) ;;
    picked*)
      description=${out#picked
}
      if printf '%s' "$description" | "$clipboard"; then
        ctl eval 'globalThis.__trexPickNote?.("Copied to the clipboard")' >/dev/null 2>&1
      else
        ctl eval 'globalThis.__trexPickNote?.("trex couldn’t copy to the clipboard")' >/dev/null 2>&1
      fi
      exit 0 ;;
    *) exit 0 ;;
  esac
done
