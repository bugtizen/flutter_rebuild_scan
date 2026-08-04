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
