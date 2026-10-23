#!/usr/bin/env bash
# Assert that the patch series really removed cloud bootstrap and telemetry.
# Runs against a patched upstream checkout. Fails loudly if a patch stopped
# taking effect after an upstream change.
set -euo pipefail

root="${1:?usage: verify-strip.sh <patched-upstream-checkout>}"
cd "$root"

fail() {
  echo "verify: $*" >&2
  exit 1
}

grep -q "export const hasCloudPublicConfig: boolean = false;" \
  apps/server/src/cloud/publicConfig.ts ||
  fail "server cloud config is still configurable"

grep -q "if (!hasCloudPublicConfig) {" apps/server/src/server.ts ||
  fail "server still reconciles cloud tunnels"
grep -q "Deferred.succeed(cloudLinkParked, undefined)" apps/server/src/server.ts ||
  fail "server startup gate is never signalled without cloud config"
grep -q "if (!hasCloudPublicConfig) return null;" \
  apps/server/src/relay/AgentAwarenessRelay.ts ||
  fail "the relay client can still publish agent activity"

! grep -q "connectCommand" apps/server/src/binCli.ts ||
  fail "t3 connect is still registered"

grep -q "export const layer = AnalyticsService.layerTest;" \
  apps/server/src/telemetry/AnalyticsService.ts ||
  fail "product analytics is still live"

grep -q 'Config.Boolean("T3CODE_TELEMETRY_ENABLED").pipe(Config.withDefault(false))' \
  apps/server/src/telemetry/AnalyticsService.ts ||
  fail "product analytics defaults to enabled"

grep -q "disabled: true" packages/shared/src/otelEnvironment.ts ||
  fail "OpenTelemetry environment is still read"
grep -q "isRelayTracingEnabled = (_env" packages/shared/src/otelEnvironment.ts ||
  fail "relay tracing is still configurable"

! grep -q "TelemetryExportSettings" \
  apps/web/src/components/settings/DiagnosticsSettings.tsx ||
  fail "OTLP export settings are still rendered"

grep -q "return false;" apps/web/src/cloud/publicConfig.ts ||
  fail "web cloud UI is still configurable"

grep -q "return false;" apps/mobile/src/features/cloud/publicConfig.ts ||
  fail "mobile cloud UI is still configurable"

grep -q "Unplugged build: no OTA checks" apps/mobile/app.config.ts ||
  fail "mobile OTA updates are still enabled"

grep -q "showUpdateDetails && state !== null && state.releaseNotes.length > 0" \
  apps/web/src/components/sidebar/SidebarUpdatePill.tsx ||
  fail "desktop update release notes are still hidden on the latest channel"
! grep -q 'channel !== "nightly"' \
  apps/web/src/components/sidebar/SidebarUpdateReleaseNotes.tsx ||
  fail "desktop update release notes are still hidden on the latest channel"

! grep -q "repoEnv.VITE_CLERK" apps/web/vite.config.ts ||
  fail "web build still injects cloud config"

# No analytics or tracing endpoint may survive into shipped bundles.
if [[ -d apps/web/dist || -d apps/server/dist ]]; then
  for needle in "ingest.t3.codes" "us.i.posthog.com" "phc_"; do
    if grep -rIl --exclude="*.map" "$needle" apps/web/dist apps/server/dist 2>/dev/null; then
      fail "built bundle still contains $needle"
    fi
  done
fi

echo "verify: unplugged strip is intact"
