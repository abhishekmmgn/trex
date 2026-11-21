# Shell helpers shared by bin/trex, bin/trex-agent, bin/trex-setup and
# tests/lib.sh. Bash; sourced, never run.
#
#   TREX_DIR             this checkout
#   REX                  the rex CLI: $REX, else rex on PATH, else where Rex installs it
#   die MESSAGE          print "trex: MESSAGE" on stderr and exit 1
#   main_checkout        this repository's main checkout (not a linked worktree)
#   pinned_kb REPO|PIN  the pinned KittyBrowser, from lua/trex/pin.lua (the one place it lives)
#   kb_rows_in LIST BLOCKS   the rows of `kb list` output LIST whose pane is one of BLOCKS
#   kb_field NAME...     from `kb list` rows on stdin, the columns NAME: number, url, pane, id
#
# kb_rows_in and kb_field are the one place shell code reads `kb list`'s format:
# one line per kb, "number<TAB>url<TAB>pane<TAB>id". A kb that isn't answering
# has no pane or id, so it is never in BLOCKS.

TREX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

REX=${REX:-$(command -v rex || echo "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")}

die() { printf 'trex: %s\n' "$*" >&2; exit 1; }

# The main checkout of this repository (not a linked worktree): where Rex's config and the
# trex link on PATH point.
main_checkout() {
  local common
  if common=$(git -C "$TREX_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    dirname "$common"
  else
    printf '%s\n' "$TREX_DIR"
  fi
}

pinned_kb() { # REPO|PIN
  sed -n "s/^M\\.$1 = \"\\(.*\\)\"\$/\\1/p" "$TREX_DIR/lua/trex/pin.lua"
}

kb_rows_in() { # LIST BLOCKS
  awk -F '\t' 'NR == FNR { if ($0 != "") want[$0] = 1; next } $3 in want' \
    <(printf '%s\n' "$2") <(printf '%s\n' "$1")
}

kb_field() { # NAME... (several are printed tab-separated, in `kb list`'s order)
  local name fields=
  for name in "$@"; do
    case $name in
      number) fields=$fields,1 ;;
      url) fields=$fields,2 ;;
      pane) fields=$fields,3 ;;
      id) fields=$fields,4 ;;
      *) die "kb_field: no column $name" ;;
    esac
  done
  cut -f"${fields#,}"
}
