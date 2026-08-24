#!/usr/bin/env bash
# Build the static site and publish it to Vercel by pushing it.
#
# Vercel has no OCaml toolchain, so nothing here can be built there. What Vercel
# can do is serve files -- so the build happens on this machine and the *output*
# is what gets pushed. `vercel.json` sets `buildCommand` and `installCommand` to
# null, which makes the deployment a plain static upload of four files.
#
# Those four files do not go on `ocaml-port`. A megabyte of generated JavaScript
# in the history of the branch someone is meant to read is exactly what `site/`
# is gitignored to avoid. They go on their own branch as a single orphan commit
# that is *replaced* rather than appended to on each deploy: it shares no history
# with the source, contains no source, and names the commit it was built from --
# so "what is actually live, and from what?" has an answer.
#
# `master` and the production URL are untouched. This lands on the deploy
# branch's own Vercel URL; promoting that to production is a decision, and it is
# made in the Vercel dashboard rather than by a script.
#
# Usage, from inside WSL:   ./scripts/deploy_vercel.sh
set -euo pipefail

BRANCH="${SYMBAROUM_DEPLOY_BRANCH:-vercel-deploy}"
REMOTE="${SYMBAROUM_DEPLOY_REMOTE:-origin}"

cd "$(dirname "$(readlink -f "$0")")/.."
repo=$PWD

# The commit message claims a source commit, and this branch is the only record
# of what is serving -- so a dirty tree would make the one durable claim here a
# false one. Override for a deliberate experiment.
if [[ "${SYMBAROUM_DEPLOY_ALLOW_DIRTY:-0}" != 1 ]]; then
  if ! git diff --quiet HEAD --; then
    echo "error: working tree is dirty; the deploy would misreport its source." >&2
    echo "       Commit first, or set SYMBAROUM_DEPLOY_ALLOW_DIRTY=1." >&2
    exit 1
  fi
fi

# WSL has no SSH key of its own and deliberately never got a copy of the one on
# the Windows side. Borrow the Windows client instead -- it reads that key from
# its own home directory. BatchMode turns "hangs forever on a prompt nobody can
# see" into an error message.
if [[ -z "${GIT_SSH_COMMAND:-}" && ! -s "$HOME/.ssh/id_ed25519" ]]; then
  win_ssh=/mnt/c/Windows/System32/OpenSSH/ssh.exe
  if [[ -x $win_ssh ]]; then
    export GIT_SSH_COMMAND="$win_ssh -o BatchMode=yes"
  fi
fi

source_commit=$(git rev-parse HEAD)
source_branch=$(git rev-parse --abbrev-ref HEAD)

./scripts/build_site.sh

# Assemble the deployment in a scratch directory and turn it into a commit with
# plumbing. A temporary index means no checkout and no branch switch, so the
# working tree of the source branch is never touched -- which is the whole reason
# generated files can be published without ever being in it.
staging=$(mktemp -d)
index=$(mktemp -u)
cleanup() { rm -rf "$staging" "$index"; }
trap cleanup EXIT

mkdir -p "$staging/site"
cp site/main.bc.js site/index.html site/app.css site/index.css "$staging/site/"
cp vercel.json "$staging/"

export GIT_INDEX_FILE=$index
git --git-dir="$repo/.git" --work-tree="$staging" add --all --force -- "$staging"
tree=$(git --git-dir="$repo/.git" write-tree)
unset GIT_INDEX_FILE

raw=$(stat -c%s site/main.bc.js)
gz=$(gzip -c site/main.bc.js | wc -c)

# No parent: each deploy is a fresh root commit, so the branch never accumulates
# superseded bundles.
commit=$(git commit-tree "$tree" <<MSG
deploy: site built from ${source_commit:0:7}

Every file here is build output, produced by scripts/deploy_vercel.sh. The
source is on \`$source_branch\` at $source_commit.

main.bc.js: $((raw / 1024)) KB raw, $((gz / 1024)) KB gzipped.
MSG
)

git update-ref "refs/heads/$BRANCH" "$commit"
git push --force "$REMOTE" "$commit:refs/heads/$BRANCH"

printf '\ndeployed %s -> %s/%s\n' "${commit:0:7}" "$REMOTE" "$BRANCH"
