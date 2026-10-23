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
debug-signed. Windows installs check this repository's releases for updates.
Mobile OTA updates are disabled, and Linux/Android installs update manually.

Release notes carry the upstream stable changelog, and the desktop update prompt
shows those changes on the `latest` channel as well, not just on nightly builds.

## Patches

`patches/` is a `git apply` series against a specific upstream tag. The base
tag is recorded in `upstream-base.txt`. Applying the series to a newer tag can
fail; that failure is the signal that the patches need a refresh.

```
./scripts/apply-patches.sh /path/to/upstream-checkout
./scripts/verify-strip.sh /path/to/upstream-checkout
```

To check the series against another upstream tag:

```
./scripts/check-patches.sh v0.1.1
```

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
