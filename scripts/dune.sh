#!/usr/bin/env bash
# Run dune inside WSL2 with the layout §0.1c of PORT_TODO.md decided on.
#
# Why this wrapper exists: the repo is canonical on the Windows side, reached
# over the 9p /mnt/c mount, which is ~78x slower than ext4 for the small-file
# I/O dune generates. Sources stay there (one working tree, no sync risk) but
# build output must not. DUNE_BUILD_DIR moves it to ext4, and the switch is a
# named global switch rather than a local _opam/ on the mount.
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

# Keep _build off the 9p mount. Per-switch so switches can't collide.
export DUNE_BUILD_DIR="${DUNE_BUILD_DIR:-$HOME/build/symbaroum-$SWITCH}"
mkdir -p "$DUNE_BUILD_DIR"

cd "$(dirname "$(readlink -f "$0")")/.."
exec dune "$@"
