#!/usr/bin/env bash
# Pin patched dependencies for lockfile-free release installs.
#
# Upstream v0.1.2 records patched packages in patchedDependencies but leaves
# some dependency ranges loose. When a newer registry release appears, the
# release scripts' lockfile-free `vp install --prod` resolves it and pnpm fails
# with ERR_PNPM_UNUSED_PATCH. Upstream fixed this on main by pinning every
# patched package in `overrides` (22840ab9). Until the patch base moves to a
# release that carries that fix, add the node-pty pin here.
#
# Run this after the workspace lockfile install and before the archive or
# desktop sidecar install.
set -euo pipefail

workspace="${1:-pnpm-workspace.yaml}"
test -f "$workspace"

version="$(sed -n 's/^  node-pty@\([^:]*\): patches\/.*/\1/p' "$workspace" | head -n 1)"
test -n "$version"

if grep -Fqx "  node-pty: ${version}" "$workspace"; then
  exit 0
fi

grep -q '^overrides:$' "$workspace"
sed -i "s/^overrides:\$/overrides:\n  node-pty: ${version}/" "$workspace"
grep -n 'node-pty' "$workspace"
