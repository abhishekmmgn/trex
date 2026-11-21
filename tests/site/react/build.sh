#!/bin/sh
# Rebuilds the React fixtures for tests/test_pick_react.sh: the app in src/,
# bundled with React 18 into 18/app.js and with React 19 into 19/app.js, in
# development (so React keeps its debug info) with source maps. The output is
# checked in, so tests need no network or npm. Run this only to change them.
#
#   tests/site/react/build.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for react in 18.3.1 19.1.0; do
  major=${react%%.*}
  mkdir -p "$work/$major"
  (cd "$work/$major" && npm init -y >/dev/null && npm install --silent "react@$react" "react-dom@$react" esbuild@0.25.0)
  # Built from a copy beside its node_modules, so the map's sources are
  # src/… and node_modules/…, not this machine's paths.
  cp -R "$here/src" "$work/$major/src"
  (cd "$work/$major" && node_modules/.bin/esbuild src/main.jsx --bundle --outfile="$here/$major/app.js" \
    --sourcemap --sources-content=false --jsx=automatic --jsx-dev \
    --define:process.env.NODE_ENV='"development"' --minify-whitespace --log-level=warning)
  # The map's sources are relative to the map; point them at src/ beside it.
  /usr/bin/python3 - "$here/$major/app.js.map" "$work/$major" <<'PY'
import json, os, sys
path, root = sys.argv[1], sys.argv[2]
m = json.load(open(path))
out = os.path.dirname(path)
m["sources"] = [os.path.relpath(os.path.normpath(os.path.join(out, s)).replace(os.path.realpath(root), os.path.join(out, "..")), out)
                if os.path.realpath(root) in os.path.normpath(os.path.join(out, s)) else s for s in m["sources"]]
json.dump(m, open(path, "w"))
PY
done
