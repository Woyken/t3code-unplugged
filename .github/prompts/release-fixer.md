# Repair the unplugged release build for {{TAG}}

The `Release` workflow failed for upstream **{{TAG}}** even though the unplugged
patch series applies cleanly. The failure is in a build or publish step, not in
the patch series.

Context:

- Failed release run: {{RUN_URL}}
- Failed jobs: `./fix-input/failed-jobs.txt`
- Failure log (last lines of each failed job): `./fix-input/failure.log`
- Upstream checkout: `./upstream`, checked out at `{{TAG}}` with the patch series applied
- Previous upstream stable tag: `{{PREVIOUS}}` (fetched for comparison; `none` if unknown)
- Patch base: `{{BASE}}` (usually the same tag as `{{TAG}}` after a patch refresh)
- Reference diff: `./fix-input/upstream-build-diff.txt` and
  `./fix-input/upstream-build-diff-stat.txt` (changes in build files from
  `{{PREVIOUS}}` to `{{TAG}}`, when available)
- Release workflow: `.github/workflows/release.yml`
- Helper scripts: `scripts/`
- Patch series: `patches/*.patch` (already applied to `upstream/`)
- Base marker: `upstream-base.txt` (keep it at `{{TAG}}`)

Goal: make the release build work with `{{TAG}}` while preserving what the
release produces and how it is validated.

Start with the reference diff. Build drift almost always comes from a change in
upstream's own release workflow or packaging script. Read upstream's
`.github/workflows/release.yml` and `release-desktop.yml` at `{{TAG}}` and
compare them with this repository's `release.yml`. Upstream's own jobs are the
reference for how the same artifact is built today.

Known failure classes:

- **Windows payload file limit** (`WindowsPackagedPayloadValidationError`).
  Do not raise or remove the limit. Native Windows builds run `afterPack` hooks
  such as `scripts/prepare-server-compile-cache.cjs`, which add loose files that
  upstream's Linux cross-build skips. Either align the Windows job with
  upstream's cross-build or add a small patch that keeps the native-only step
  from running. Removing an intentional performance cache is acceptable when
  upstream's released artifact does not contain it; weakening the payload check
  is not.
- **CLI smoke test** (`Smoke-test CLI archive`). Check whether upstream changed
  the `t3 serve` flags, archive layout, or first-run behavior in
  `apps/server/scripts/cli.ts` and `scripts/build-cli-archive.ts`, then update
  the smoke invocation in `release.yml` to match. Never remove, skip, loosen,
  or `continue-on-error` the smoke test; if the artifact is genuinely broken by
  upstream code, explain that instead of weakening the check.
- **Version or artifact mismatch**. Check
  `scripts/update-release-package-versions.ts` and upstream's release workflow
  for the current arguments and output names before changing this repository's
  versioning.

Suggested method:

1. Read the failure log, the reference diff, `README.md`, and the failing job's
   steps in `.github/workflows/release.yml`.
2. Inspect the upstream change that caused the failure:
   `git -C upstream diff {{PREVIOUS}} {{TAG}} -- .github/workflows scripts apps/desktop apps/server/scripts package.json pnpm-workspace.yaml native`
   Read only the affected files; do not scan the whole upstream tree. If
   `{{PREVIOUS}}` is `none`, skip the diff and read upstream's workflow and
   packaging files at `{{TAG}}` directly.
3. Prefer a workflow or helper-script change. If the cause is inside upstream's
   packaging logic and the workflow cannot control it, add or update a patch in
   `patches/` (next numeric prefix) and keep `upstream-base.txt` at `{{TAG}}`.
   Reset upstream before testing a patch:
   `git -C upstream reset --hard {{TAG}}`
   `bash scripts/apply-patches.sh upstream`
4. Reproduce the failing invocation with static checks where possible. Do not
   install dependencies, run full builds, or use the network.
5. Validate:
   - `bash -n scripts/*.sh`
   - `node --check` on any edited `.mjs`/`.cjs` script
   - `bash scripts/verify-strip.sh upstream`
   - `bash scripts/typecheck-patches.sh upstream`
   - `git diff` confirms no secrets, network commands, or unpinned actions.
6. If the failure is transient or unrelated to upstream build drift, leave the
   files unchanged and explain your reasoning.

Work efficiently. Use Read, Glob, and Grep for source files. The allowlist does
cover `cat fix-input/failure.log`, `cat fix-input/upstream-build-diff.txt`,
`ls -la`, `pwd`, `git log`, and `git show`, but it does not cover compound
commands, `echo` separators, or paths outside the workspace (`/tmp`, `/home`,
pnpm stores). A denied command still costs a step. Make the first edit before
step 40, then spend the remaining budget on validation and a concise final
answer.

Rules:

- Do not edit `.github/prompts/`, `.opencode/`, or workflows other than
  `release.yml`.
- Do not change `upstream-base.txt` away from `{{TAG}}`.
- Do not weaken patch application, `verify-strip`, typechecking, smoke tests,
  payload validation, signing, or release checks.
- Do not add `pull_request_target`, unpinned actions, `curl | bash`, secret
  logging, or any network command.
- Do not change versioning, artifact names, updater metadata, or the public
  release contract unless upstream made the old behavior impossible.
- Do not run `git push`, `git clone`, `git fetch`, `git remote`, `gh`, `curl`,
  `wget`, or any network command.
- Reset `upstream/` before each attempt:
  `git -C upstream reset --hard {{TAG}}` then
  `bash scripts/apply-patches.sh upstream`.
- If you cannot fix it, restore your edits with
  `git checkout -- .github/workflows/release.yml`,
  `git checkout -- scripts/`, `git checkout -- README.md`,
  `git checkout -- patches/`, and `git checkout -- upstream-base.txt`,
  then explain what blocks you. Do not leave partial edits.

Final answer: summarize the upstream change that caused the failure, each file
you changed, the commands you ran and their results, and any remaining risk or
uncertainty.
