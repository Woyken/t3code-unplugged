# Repair the unplugged release build for {{TAG}}

The `Release` workflow failed for upstream **{{TAG}}** even though the unplugged
patch series applies cleanly. The failure is in a build or publish step, not in
the patch series.

Context:

- Failed release run: {{RUN_URL}}
- Failed jobs: `./fix-input/failed-jobs.txt`
- Failure log (last lines of each failed job): `./fix-input/failure.log`
- Upstream checkout: `./upstream`, checked out at `{{TAG}}` with the patch series applied
- Previous base: `{{BASE}}` (fetched for comparison)
- Release workflow: `.github/workflows/release.yml`
- Helper scripts: `scripts/`
- Patch series: `patches/*.patch` (already applied to `upstream/`)
- Base marker: `upstream-base.txt` (do not edit it)

Goal: make the release build work with `{{TAG}}` while preserving what the
release produces and how it is validated.

A failure in `Smoke-test CLI archive` means the packaged binary started from the
archive did not report the expected version or never answered HTTP requests on
its loopback port. In that case check whether upstream changed the `t3 serve`
flags, the archive layout, or the first-run behavior in
`apps/server/scripts/cli.ts` and `scripts/build-cli-archive.ts`, and update the
smoke invocation in `release.yml` to match. Never remove, skip, loosen, or
`continue-on-error` the smoke test; if the artifact is genuinely broken by
upstream code, explain that instead of weakening the check.

Suggested method:

1. Read `README.md`, `.github/workflows/release.yml`, the scripts used by the
   failing job, and `fix-input/failure.log`.
2. Inspect how upstream changed the interface the failing job uses:
   `git -C upstream diff {{BASE}} {{TAG}} -- package.json apps/server/scripts apps/server/vite.config.ts scripts .github/workflows`
   Also inspect any other paths named in the failure.
3. Reproduce the failing invocation with static checks where possible. Do not
   install dependencies, run full builds, or use the network.
4. Update only `.github/workflows/release.yml`, `scripts/**`, and `README.md`.
   Keep the change minimal and specific to the upstream change.
5. Validate with `bash -n scripts/*.sh`, inspect `git diff`, and make sure no
   secrets, network commands, or unpinned actions were added.
6. If the failure is transient or unrelated to upstream build drift, leave the
   files unchanged and explain your reasoning.

Rules:

- Do not edit `patches/`, `upstream-base.txt`, `.github/prompts/`, `.opencode/`,
  or workflows other than `release.yml`.
- Do not weaken patch application, `verify-strip`, smoke tests, signing, or
  release checks.
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
  `git checkout -- .github/workflows/release.yml scripts/ README.md` and explain
  what blocks you. Do not leave partial edits.

Final answer: summarize the upstream change that caused the failure, each file
you changed, the commands you ran and their results, and any remaining risk or
uncertainty.
