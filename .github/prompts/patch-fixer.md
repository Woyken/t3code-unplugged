# Repair the unplugged patch series for {{TAG}}

A check found that the current patch series no longer works against upstream
**{{TAG}}**. It can fail in any of three ways, all recorded in
`./fix-input/apply.log`:

- a patch no longer applies (`git apply` rejects hunks)
- a patch applies but `verify-strip.sh` fails (the unplugged guarantee was lost)
- a patch applies and is stripped but `tsc` fails: the patch still references a
  symbol that upstream renamed or removed

Context:

- New upstream tag: `{{TAG}}`
- Previous base tag: `{{BASE}}`
- Upstream checkout: `./upstream` (checked out at `{{TAG}}`; `{{BASE}}` was fetched for comparison)
- Patch series: `./patches/*.patch` (applied in filename order)
- Base marker: `./upstream-base.txt`
- Failure log: `./fix-input/apply.log`
- Rejected hunks: `./fix-input/rejects/` (flattened paths, copied from the failing checkout)

Goal: make the series apply, stay stripped, and typecheck against `{{TAG}}`
again while preserving the intent of each patch.

Suggested method:

1. Read `README.md` (the "Patches" and "What a build removes" sections), the
   patch files, and `fix-input/apply.log`. For a typecheck failure the log ends
   with `tsc` errors naming the patched file and line.
2. List the files touched by the series:
   `git apply --stat patches/*.patch`
3. Inspect how upstream changed those files:
   `git -C upstream diff {{BASE}} {{TAG}} -- <paths>`
   Read only the affected files; do not scan the whole upstream tree.
4. Reset the checkout before each attempt:
   `git -C upstream reset --hard {{TAG}}`
   `git -C upstream clean -fd`
5. Reproduce the failure with the normal script:
   `bash scripts/apply-patches.sh upstream`
   For the failing patch, inspect the rejected hunks with:
   `bash scripts/apply-patch.sh <name>.patch`
   and read the generated `.rej` files in `upstream/`.
6. Update the failing `patches/<name>.patch` directly. Adjust context, hunk
   line counts, and identifiers to match the new upstream source. Keep the
   change minimal and preserve the patch's intent. When upstream removed a
   symbol a patch relied on, make the patch self-contained instead of pointing
   at the missing symbol.
7. Reset `upstream/` and repeat until the full series applies:
   `bash scripts/apply-patches.sh upstream`
8. Verify the unplugged guarantees:
   `bash scripts/verify-strip.sh upstream`
9. Typecheck the patched tree:
   `bash scripts/typecheck-patches.sh upstream`
   This installs the server dependency graph on first use, so it can take a few
   minutes. Fix the patch that causes the error, not `upstream/`.
10. Only after all three commands pass, update `upstream-base.txt` to `{{TAG}}`.

Rules:

- Do not modify `scripts/`, `.github/`, `README.md`, `fix-input/`, or any other
  file outside `patches/`, `upstream-base.txt`, and the throwaway `upstream/`
  checkout.
- Do not run `git push`, `git clone`, `git fetch`, `git remote`, `gh`, `curl`,
  `wget`, or any network command. The exception is `vp install` inside
  `scripts/typecheck-patches.sh`, which downloads packages from the registry.
- Do not drop a security fix or skip a behavior just to make the patches apply
  or typecheck. If upstream removed the behavior entirely, say so and remove
  only the patch that is now obsolete.
- Do not reorder or rename existing patches unless the change is required. If
  you add a patch, use the next numeric prefix.
- If you cannot fix the series, restore `patches/` and `upstream-base.txt` to
  their original state and explain what blocks you. Do not leave partial edits.
  Use `git checkout -- patches/` and `git checkout -- upstream-base.txt`.

Final answer: summarize each patch you changed, the commands you ran and their
results, and any remaining risk or uncertainty.
