#!/usr/bin/env bash
# Build the static site into ./site.
#
# The output is four files and nothing runs on the host, which is what lets it
# be served by anything: `python3 -m http.server` from inside ./site is enough,
# and so is Vercel with `vercel.json` as it stands.
#
# Usage, from inside WSL:   ./scripts/build_site.sh
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
./scripts/dune.sh build --profile release web/main.bc.js

rm -rf site
mkdir -p site
cp _build/default/web/main.bc.js \
   _build/default/web/index.html \
   _build/default/web/app.css \
   _build/default/web/index.css \
   site/
chmod u+w site/*

raw=$(stat -c%s site/main.bc.js)
gz=$(gzip -c site/main.bc.js | wc -c)
printf 'site/ built: %d KB raw, %d KB gzipped\n' "$((raw / 1024))" "$((gz / 1024))"
