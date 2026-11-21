#!/bin/sh
# Waits for the pick in a Browser Pane's page, then copies its description to
# the clipboard and pastes it into the Agent Pane. pick.lua starts it in the
# background once pick.js has turned pick mode on; it ends when the user
# picks, cancels, or the page goes away.
#
#   pick-wait.sh KB KB_ID CLIPBOARD REX SESSION AGENT AGENT_NAME WHY
#
# KB is the kb binary, KB_ID the Browser Pane's kb ("N-xxxx"), CLIPBOARD a
# command that reads the text to copy on stdin (/usr/bin/pbcopy), REX the rex
# CLI. AGENT is the Agent Pane's block in Rex session SESSION and AGENT_NAME
# what runs there ("Claude Code"); with no AGENT, WHY says why there is none.
#
# Each wait asks the page for at most 25 s, because kb gives up on a request
# after 30 s (REQUEST_TIMEOUT in its src/devtools.rs). A wait that fails anyway
# is retried while pick mode is still on; once the page is gone or pick mode is
# off, this exits. The page ends pick mode itself if no wait comes for 90 s.

kb=$1 id=$2 clipboard=$3 rex=$4 session=$5 agent=$6 agent_name=$7 why=$8

# Never with a DevTools Pane's KB_SOCKET, which beats -i.
unset KB_SOCKET KB_INSTANCE
# Rex runs this with no locale, and pbcopy then reads its input as Mac Roman
# (× arrives as √ó). The description is UTF-8.
export LC_CTYPE=UTF-8

ctl() { "$kb" ctl -i "$id" "$@"; }

# Shows TEXT in a note on the page. TEXT must not hold a double quote.
note() { ctl eval "globalThis.__trexPickNote?.(\"$1\")" >/dev/null 2>&1; }

# Pastes JSON_TEXT (a JSON string) into the Agent Pane. Focus stays in the
# Browser Pane, so the user can pick more elements; each pick adds to what
# waits unsent in the agent's input. A paste,
# so a program with bracketed paste on (Claude Code, Codex, Cursor) gets it as
# pasted text and its newlines don't send it. Only if an agent still runs
# there: it may have quit since the pick began, and a shell would run the text.
paste_to_agent() { # JSON_TEXT
  "$rex" block call -s "$session" --block "$agent" process 2>/dev/null |
    grep -Eq '"argv0":"([^"]*/)?(claude|codex|cursor-agent|agent)"' || return 1
  printf '{"session_id":"%s","block_id":"%s","event":{"type":"paste","payload":{"text":%s}}}' \
    "$session" "$agent" "$1" | "$rex" api call block.event - >/dev/null 2>&1
}

while :; do
  if ! out=$(ctl eval 'globalThis.__trexPick ? globalThis.__trexPick.wait(25000) : "gone"' 2>/dev/null); then
    on=$(ctl eval 'globalThis.__trexPick?.active() ? "on" : "off"' 2>/dev/null) || exit 0
    [ "$on" = on ] || exit 0
    continue
  fi
  case $out in
    pending) ;;
    picked*)
      # "picked", the description as a JSON string, then the description.
      rest=${out#picked
}
      json=${rest%%
*}
      description=${rest#*
}
      copied=no
      printf '%s' "$description" | "$clipboard" && copied=yes
      if [ -n "$agent" ] && paste_to_agent "$json"; then
        if [ $copied = yes ]; then note "Sent to $agent_name and copied"; else note "Sent to $agent_name (couldn’t copy it)"; fi
      elif [ -n "$agent" ]; then
        if [ $copied = yes ]; then note "Copied to the clipboard ($agent_name is no longer running there)"
        else note "trex couldn’t copy or send it"; fi
      else
        if [ $copied = yes ]; then note "Copied to the clipboard ($why)"; else note "trex couldn’t copy to the clipboard"; fi
      fi
      exit 0 ;;
    *) exit 0 ;;
  esac
done
