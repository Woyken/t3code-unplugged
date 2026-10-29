# T3 Code Unplugged

T3 Code with the cloud removed. This is not a fork: the repository tracks
[`pingdotgg/t3code`](https://github.com/pingdotgg/t3code) and applies a small
patch series at build time, so every release is built from an upstream tag plus
these patches.

## What a build removes

| Removed | Where |
| --- | --- |
| T3 Connect (accounts, environment links, managed tunnels, relay client) | server cloud bootstrap, CLI `t3 connect`, web/mobile cloud gates |
| Product analytics (PostHog) | `AnalyticsService` is a no-op and defaults off |
| Relay tracing (Axiom) | relay tracing config resolves to `null` |
| OpenTelemetry export (OTLP traces/metrics/logs) | `OtelEnvironment.load` reports disabled; Diagnostics export UI is gone |
| Expo OTA updates (mobile) | mobile config sets `updates.enabled: false` |

## What a build keeps

- Local and Tailscale remote access, pairing URLs, and direct/LAN connections.
- Local logs, local trace files, and the Diagnostics process/resource views.
- Every provider, project, thread, and editor feature.

Local logs are intentionally kept: "no logs" here means no log, trace, or
metric shipping to a remote collector.

## Releases

Each upstream **stable** tag (`vX.Y.Z`, no `-nightly`/`-preview`/`-pr`
suffix) produces one release:

```
vX.Y.Z-unplugged.N
```

`N` starts at 1. The desktop app, CLI archive, and Android APK all carry that
version. The workflow runs on an hourly schedule, but GitHub's scheduled
workflows are best-effort and can be delayed or skipped; trigger the `Release`
workflow manually with `upstream_tag` to build a tag immediately. It skips tags
it already released.

Artifacts:

- `t3-X.Y.Z-unplugged.N-linux-x64.tar.gz` – standalone Linux CLI/server (x64)
- `t3-X.Y.Z-unplugged.N-linux-arm64.tar.gz` – standalone Linux CLI/server (arm64)
- `T3-Code-X.Y.Z-unplugged.N-x64.exe` – Windows NSIS installer
- `t3code-unplugged-X.Y.Z-unplugged.N-android.apk` – Android APK
- `latest.yml` + `T3-Code-X.Y.Z-unplugged.N-x64.exe.blockmap` – Windows updater metadata
- `SHA256SUMS`

Windows builds are unsigned, so SmartScreen may warn; the Android APK is
debug-signed. Windows and Linux CLI installs check this repository's releases for
updates. Mobile OTA updates are disabled, and the Android app updates manually.

Release notes carry the upstream stable changelog, and the desktop update prompt
shows those changes on the `latest` channel as well, not just on nightly builds.

## Patches

`patches/` is a `git apply` series against a specific upstream tag. The base
tag is recorded in `upstream-base.txt`. Applying the series to a newer tag can
fail; a patch can also keep applying while referencing a symbol upstream
renamed or removed. Either failure is the signal that the patches need a
refresh.

```
./scripts/apply-patches.sh /path/to/upstream-checkout
./scripts/verify-strip.sh /path/to/upstream-checkout
./scripts/typecheck-patches.sh /path/to/upstream-checkout
```

`typecheck-patches.sh` installs the server dependency graph on first use and
then runs `tsc` over `t3` and `@t3tools/shared`, which covers every TypeScript
file the series rewrites.

To check the series against another upstream tag:

```
./scripts/check-patches.sh v0.1.1
```

`check-patches.sh` applies the series and runs `verify-strip`; set
`T3CODE_PATCH_TYPECHECK=1` to typecheck too.

Refreshing after an upstream change:

1. Check out the new upstream tag.
2. `./scripts/apply-patches.sh <checkout>` and resolve rejected hunks by hand.
3. Regenerate the affected files:

   ```
   cd <checkout>
   git diff -- <files> > /path/to/t3code-unplugged/patches/<patch>.patch
   ```

4. Update `upstream-base.txt`, run `./scripts/check-patches.sh <new-tag>`, and
   commit both the patch changes and the new base tag.

## Automated drift fixes

`.github/workflows/patch-drift.yml` reacts to a failed `Release` run. It runs
only after a failure; the release preflight already applies the series, runs
`verify-strip`, and typechecks the patched tree, so it needs no timer. It
repairs two kinds of drift in the same flow:

- **Patch drift**: the series no longer applies, `verify-strip` fails, or the
  patched tree does not typecheck. The `patch-fixer` agent refreshes
  `patches/` and `upstream-base.txt`.
- **Build drift**: the series still applies, but a build or publish step no
  longer matches a new upstream tag. The `release-fixer` agent gets the failed
  job logs and may update `.github/workflows/release.yml`, `scripts/`, and
  `README.md`, but not the patch series or other workflows.

Both agents use `opencode/deepseek-v4.1-flash-free#high`. They need the
environment secret `OPENCODE_API_KEY` in the repository environment `autoFixer`.
The free OpenCode model is limited-time; it still requires an OpenCode Console
API key, but not a paid DeepSeek key.

The result is validated in a clean checkout and published as a regular PR on
`patch-fix/<tag>` or `build-fix/<tag>`; nothing is auto-merged and the agents
never receive a GitHub write token. The publish job runs
`check-patches.sh` with `T3CODE_PATCH_TYPECHECK=1`, so a proposed patch fix is
only offered if the series still applies, strips, and typechecks; for build
drift it also runs `bash -n` over the scripts and parses every workflow as YAML
before opening the PR.

Manual runs:

```
gh workflow run patch-drift.yml
gh workflow run patch-drift.yml -f upstream_tag=v0.1.3 -f dry_run=true
gh workflow run patch-drift.yml -f run_id=123456789 -f dry_run=true
gh workflow run patch-drift.yml -f force=true
```

`dry_run` runs the agent and agent-side checks but skips clean-checkout
validation and the PR. `force` reruns the agent when an open fix PR or a
previous failed attempt exists. After a failed attempt, a hidden marker is
recorded on the `patch-drift` or `release-drift` issue so subsequent release
failures do not retry the same tag indefinitely. When a release succeeds, the
matching open issues are closed automatically. The fixers run on `main`; the
`autoFixer` environment is restricted to that branch.

Review AI-generated PRs before merging. The patch fixer changes the patch
series; the release fixer can change the release workflow and build scripts.
`verify-strip` checks the unplugged guarantees, but it cannot prove that a patch
or workflow change is semantically correct or benign.

## Tests

Upstream tests that assert cloud configuration is honored or that analytics is
on by default (for example `apps/*/src/cloud/publicConfig.test.ts`,
`AnalyticsService.test.ts`, `settingsSearch.test.ts`) now assert the opposite
behavior. The release workflow builds and verifies the strip; it does not run
the upstream test suite.

## Building locally

```
./scripts/apply-patches.sh /path/to/upstream-checkout
cd /path/to/upstream-checkout
vp install
vp run build:desktop
```

The release workflow is the reference for each target's exact commands.
