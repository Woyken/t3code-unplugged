#!/usr/bin/env bash
# Typecheck a patched upstream checkout.
#
# A patch can keep applying cleanly and still reference a symbol upstream
# renamed or removed. `git apply` and verify-strip.sh cannot see that, but tsc
# can, so the release preflight, the drift fixer, and CI run this. The web
# workspace has no typecheck script, so the patched web files are also checked
# for undefined names.
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

# The patches add and rewrite web components, but the web workspace has no
# typecheck script upstream and `vp build` strips types without checking them.
# A patched web file can reference a name it never imported, build fine, and
# throw when the component first renders. Check the web files the series touches
# for undefined names. Imports are not resolved here: the unresolvable modules
# are expected, while a missing local import is reported as an undefined name.
web_files=()
while IFS= read -r file; do
  web_files+=("$file")
done < <(
  {
    git diff --name-only --diff-filter=AM -- 'apps/web/*.ts' 'apps/web/*.tsx'
    git ls-files --others --exclude-standard -- 'apps/web/*.ts' 'apps/web/*.tsx'
  } | sort -u
)

if (( ${#web_files[@]} > 0 )); then
  undefined_names="$(
    vp exec effect-tsgo tsc \
      --noEmit \
      --noResolve \
      --skipLibCheck \
      --jsx react-jsx \
      --target esnext \
      --module preserve \
      --moduleResolution bundler \
      --lib ES2023,ES2024.Promise,ESNext.Disposable,DOM,DOM.Iterable \
      "${web_files[@]}" 2>&1 |
      grep -E 'error TS(2304|2552):' || true
  )"
  if [[ -n "$undefined_names" ]]; then
    echo "error: patched web files reference names they do not import:" >&2
    printf '%s\n' "$undefined_names" >&2
    exit 1
  fi
fi
