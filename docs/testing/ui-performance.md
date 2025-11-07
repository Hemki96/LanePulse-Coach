# UI & Performance Testing Strategy

This document outlines how we verify the real-time multi-stream dashboards in **LanePulse Coach**.

## Goals

- Ensure the board and scoreboard layouts render correctly for multiple simultaneous telemetry streams.
- Detect regressions in user interactions (tile selection, detail pane visibility, segmented control navigation).
- Track performance characteristics (launch time, CPU, memory, application frame timing) for multi-stream scenarios.
- Capture latency metrics end-to-end and surface them both in analytics events and optional CI reports.

## Automated UI Scenarios

The `LanePulse CoachUITests` target contains purpose-built tests in `MultiStreamBoardUITests.swift`:

- `testBoardDisplaysAllMultiStreamTiles` seeds four athletes/sensors, opens the board, verifies tile count and captures a reference screenshot attachment.
- `testSelectingTileShowsDetailPane` validates tap interactions and ensures the detail pane renders the selected athlete.
- `testSwitchingToScoreboardDisplaysCards` switches the segmented control to the scoreboard and asserts that condensed cards are shown.
- `testMultiStreamPerformanceMetrics` runs `measure(metrics:)` with launch, CPU, memory, and signpost metrics to detect regressions under the multi-stream load fixture.

All UI tests launch the app with the `--uitest-multi-stream` argument. The `LanePulse_CoachApp` checks for this flag and bootstraps an in-memory Core Data store populated with deterministic multi-stream fixtures.

## Latency Monitoring

`LatencyMonitor` records per-stream latency by comparing the most recent sample timestamp to the current time whenever snapshots refresh. The monitor:

- Emits analytics events (`latency_observed`, `latency_warning`, `latency_critical`) with millisecond precision.
- Logs warnings/errors if thresholds (`warning = 2s`, `critical = 5s`) are exceeded.
- Optionally writes a JSON report when the `LATENCY_REPORT_PATH` environment variable is set. CI pipelines can harvest this file for dashboards or trend analysis.

## CI & Reporting Hooks

- **UI tests**: Run with `xcodebuild test -scheme "LanePulse Coach" -destination "platform=iOS Simulator,name=iPhone 15"`. The seeded fixtures guarantee deterministic tile counts.
- **Latency report**: Configure the CI workflow to export `LATENCY_REPORT_PATH=$CI_ARTIFACTS_DIR/latency.json` before launching UI or performance tests. The resulting JSON contains the latest latency samples and thresholds for downstream processing.
- **Launch metric baseline**: `testLaunchPerformance` remains in `LanePulse_CoachUITests.swift` to track cold-start timings without fixtures.

## Manual Follow-Up

When investigating UI regressions:

1. Run `open LanePulse Coach.xcodeproj` and launch the preview (`AppContainer.makePreview()`) for visual checks.
2. Use the seeded multi-stream session (`Athlete 1…4`) to verify tile densities, zone colors, and detail pane updates.
3. Inspect the generated latency report if warnings appear in the logs to pinpoint streams with elevated delays.

This strategy ensures visual correctness, responsive interactions, and telemetry health for coaches monitoring multiple athletes in real time.
