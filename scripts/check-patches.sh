#!/usr/bin/env bash
# Clone an upstream tag, apply the series, and run the strip checks.
set -euo pipefail

tag="${1:?usage: check-patches.sh <upstream-tag>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

git clone --quiet --depth 1 --branch "$tag" \
  https://github.com/pingdotgg/t3code.git "$workdir/upstream"
"$repo_root/scripts/apply-patches.sh" "$workdir/upstream"
"$repo_root/scripts/verify-strip.sh" "$workdir/upstream"

# Typechecking needs a dependency install, so it is opt-in for local runs.
if [[ "${T3CODE_PATCH_TYPECHECK:-0}" == "1" ]]; then
  "$repo_root/scripts/typecheck-patches.sh" "$workdir/upstream"
  echo "check: $tag applies cleanly, is stripped, and typechecks"
else
  echo "check: $tag applies cleanly and is stripped"
fi
