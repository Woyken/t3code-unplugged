#!/usr/bin/env bash
# Typecheck a patched upstream checkout.
#
# A patch can keep applying cleanly and still reference a symbol upstream
# renamed or removed. `git apply` and verify-strip.sh cannot see that, but tsc
# can, so the release preflight, the drift fixer, and CI run this.
#
# Requires `vp` on PATH (see https://viteplus.dev); the caller installs it.
set -euo pipefail

root="${1:?usage: typecheck-patches.sh <patched-upstream-checkout>}"
cd "$root"

if ! command -v vp >/dev/null 2>&1; then
  echo "error: vp is not on PATH; install Vite+ before typechecking" >&2
  exit 1
fi

# The patches only rewrite the server, shared, web, and mobile sources. Install
# the same workspace graph the CLI build uses; the server tsconfig also includes
# `../../scripts/lib`, which needs the scripts workspace's dependencies.
vp install --filter=t3... --filter=@t3tools/web... --filter=@t3tools/scripts...
vp run --filter t3 --filter @t3tools/shared typecheck
