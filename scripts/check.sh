#!/usr/bin/env bash
# The four checks that define "green", in the order that makes a failure
# easiest to read.
#
# This is what CI would run, and since GitHub Actions is not available on this
# account it is what actually runs -- so it lives in a script rather than only in
# a workflow file and a README code block, where the three could drift apart.
#
# The second check is a claim rather than a convention: `symbaroum` is the domain
# core, and it has to build with no JavaScript runtime and no C stubs in scope.
# `bin/` lives in its own package precisely so that this keeps meaning something.
#
# Usage, from inside WSL:   ./scripts/check.sh
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

run() {
  printf '\n=== %s ===\n' "$1"
  shift
  ./scripts/dune.sh "$@"
}

run "formatting" build @fmt
run "core builds without any UI or Unix dependency" build -p symbaroum
run "tests" runtest
run "everything, including the web bundle" build

printf '\nall four green\n'
