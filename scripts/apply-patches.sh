#!/usr/bin/env bash
# Apply the unplugged patch series to a checked-out upstream tree.
set -euo pipefail

target="${1:?usage: apply-patches.sh <upstream-checkout>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $target is not a git checkout" >&2
  exit 1
fi

shopt -s nullglob
patches=("$repo_root"/patches/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "error: no patches found in $repo_root/patches" >&2
  exit 1
fi

for patch in "${patches[@]}"; do
  echo "applying $(basename "$patch")"
  git -C "$target" apply --whitespace=nowarn "$patch"
done

echo "applied ${#patches[@]} patches to $target"
