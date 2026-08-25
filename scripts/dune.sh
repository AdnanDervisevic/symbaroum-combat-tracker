#!/usr/bin/env bash
# Run dune inside WSL2 with the switch this project pins.
#
# The repo lives on ext4 at ~/symbaroum-combat-tracker; /mnt/c is abandoned for
# this work because `dune promote` silently no-ops on the 9p mount (see the
# decisions log in PORT_TODO.md). So there is nothing clever left to do about
# the build directory -- this wrapper exists only to select the named global
# opam switch, so the layout need not be re-remembered.
#
# Plain `dune` from the repo root works identically once `eval $(opam env)` has
# been run in the shell.
#
# Usage, from inside WSL:   ./scripts/dune.sh build @fmt
#                           ./scripts/dune.sh runtest
# From a Windows shell:     wsl.exe -d Ubuntu -- ./scripts/dune.sh runtest
set -euo pipefail

SWITCH="${SYMBAROUM_OPAM_SWITCH:-sct}"

if ! opam switch list --short 2>/dev/null | grep -qx "$SWITCH"; then
  echo "error: opam switch '$SWITCH' does not exist." >&2
  echo "       Create it with: opam switch create $SWITCH 5.2.0" >&2
  exit 1
fi

eval "$(opam env --switch="$SWITCH" --set-switch)"

cd "$(dirname "$(readlink -f "$0")")/.."
exec dune "$@"
