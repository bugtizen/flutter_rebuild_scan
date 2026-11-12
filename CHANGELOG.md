## 0.4.0

- Observe application frames without a continuous overlay-driven frame loop.
- Separate paint-only highlights from throttled aggregate reporting.
- Add completed engine timing summaries, a performance preset, and optional native graphs.
- Use a fixed rebuilds/second heatmap scale and correct stale frame badges and rectangles.
- Bound visible highlights, retain weak geometry references, and show a compact panel.
- Add a local mock feed comparing direct notifications with frame coalescing.
- Replace the single main demo with a backend-free gallery of eleven usage cases, integration snippets, and interactive examples.
- Add common login form and selectable feed examples, including isolated field tracking, lazy list rows, saved-row state, and Hero navigation into story details.

## 0.3.0

- Update demo doc

## 0.2.0

- Fixed release/profile targeted mode so rebuild counters do not depend on debug-only auto instrumentation.
- Deferred widget rectangle measurement until post-frame callbacks to avoid layout timing crashes during route transitions, overlays, animations, and dirty element rebuilds.
- Preserved rebuild counters when rectangle measurement is unavailable or skipped.
- Coalesced duplicate rectangle measurements per frame and skipped disposed/unmounted elements safely.
- Filtered Flutter framework private widgets from debug auto-scan by default.
- Improved public API documentation coverage for pub.dev scoring.

## 0.1.0

- Initial release candidate.
- Added `RebuildScanApp`, `RebuildScan.mark`, `RebuildScanBoundary`, `RebuildScanController`, `RebuildScanConfig`, and `HighlightMode`.
- Added rebuild registry, frame tracking, overlay painter, and draggable panel.
- Added example app and initial tests.
- Renamed package/library to `flutter_rebuild_scan`.
- Added explicit `RebuildScanMode` and `RebuildBadgeCountMode`.
- Replaced misleading `enabled` opt-in with `off`, `debugAuto`, and `targeted` modes.
- Added panel states for unsupported debug auto mode and targeted mode with no marks.
- Hardened auto-scan hook sharing and filtered Flutter framework internals by default.

