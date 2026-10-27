#!/usr/bin/env bash
# Apply one patch from patches/ to the checked-out upstream tree.
#
# This wrapper exists for the automated patch fixer. It accepts only a patch
# file name, so a caller cannot pass extra git apply options such as
# --directory or --unsafe-paths. Keep the git invocation fixed.
set -euo pipefail

name="${1:?usage: apply-patch.sh <patch-file-name>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$repo_root/upstream"

if [[ ! "${name}" =~ ^[0-9A-Za-z._-]+\.patch$ ]]; then
  echo "error: '${name}' is not a patch file name" >&2
  exit 1
fi

patch_path="$repo_root/patches/${name}"
if [[ ! -f "${patch_path}" ]]; then
  echo "error: patch not found: ${patch_path}" >&2
  exit 1
fi
if ! git -C "${target}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: ${target} is not a git checkout" >&2
  exit 1
fi

echo "applying ${name}"
git -C "${target}" apply --reject --whitespace=nowarn "${patch_path}"
