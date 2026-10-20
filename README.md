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
version. The workflow polls upstream hourly and skips tags it already
released.

Artifacts:

- `t3-X.Y.Z-unplugged.N-linux-x64.tar.gz` – standalone Linux CLI/server
- `T3 Code Unplugged-X.Y.Z-unplugged.N-x64.exe` – Windows NSIS installer
- `t3code-unplugged-X.Y.Z-unplugged.N-android.apk` – Android APK
- `SHA256SUMS`

Windows builds are unsigned. Android builds use the debug keystore unless
`ANDROID_KEYSTORE_BASE64` and its companion secrets are configured. Neither
build ships an update feed manifest, so the app does not auto-update.

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
./scripts/check-patches.sh v0.1.0
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
