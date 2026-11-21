# A stand-in for a coding agent in an Agent Pane, for tests/test_pick.sh.
# Started as `exec -a claude /bin/bash stub_agent.sh LOG`, so Rex reports it as
# claude (argv0). Bash builtins only from the loop on, so this bash stays the
# pane's foreground process (python3 would re-exec and lose the name). Like
# Claude Code, Codex and Cursor, it turns on bracketed paste; it logs every
# byte it is sent to LOG, so a test can check that a description arrived as
# one paste with nothing after it (no Enter).
log=$1
stty raw -echo
printf '\033[?2004hstub agent ready\r\n'
export LC_ALL=C
while IFS= read -r -d '' -n 1 c; do
  if [ -z "$c" ]; then printf '\n' >>"$log"; else printf '%s' "$c" >>"$log"; fi
done
