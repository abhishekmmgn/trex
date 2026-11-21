# Shell helpers shared by bin/trex, bin/trex-agent, bin/trex-setup and
# tests/lib.sh. Bash; sourced, never run.
#
#   TREX_DIR             this checkout
#   REX                  the rex CLI: $REX, else rex on PATH, else where Rex installs it
#   die MESSAGE          print "trex: MESSAGE" on stderr and exit 1
#   pinned_kb REPO|PIN   the pinned KittyBrowser, from lua/trex/pin.lua (the one place it lives)
#   kb_rows_in LIST BLOCKS   the rows of `kb list` output LIST whose pane is one of BLOCKS
#   kb_field NAME        from `kb list` rows on stdin, the column NAME: number, url, pane or id
#
# kb_rows_in and kb_field are the one place shell code reads `kb list`'s format:
# one line per kb, "number<TAB>url<TAB>pane<TAB>id". A kb that isn't answering
# has no pane or id, so it is never in BLOCKS.

TREX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

REX=${REX:-$(command -v rex || echo "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")}

die() { printf 'trex: %s\n' "$*" >&2; exit 1; }

pinned_kb() { # REPO|PIN
  sed -n "s/^M\\.$1 = \"\\(.*\\)\"\$/\\1/p" "$TREX_DIR/lua/trex/pin.lua"
}

kb_rows_in() { # LIST BLOCKS
  awk -F '\t' 'NR == FNR { if ($0 != "") want[$0] = 1; next } $3 in want' \
    <(printf '%s\n' "$2") <(printf '%s\n' "$1")
}

kb_field() { # NAME
  case $1 in
    number) cut -f1 ;;
    url) cut -f2 ;;
    pane) cut -f3 ;;
    id) cut -f4 ;;
    *) die "kb_field: no column $1" ;;
  esac
}
