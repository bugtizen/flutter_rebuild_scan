# flutter_rebuild_scan

`flutter_rebuild_scan` is a rebuild scanner for Flutter apps.
It highlights rebuilt widgets in real time and shows top rebuilders in a draggable debug panel.

## Demo

![flutter_rebuild_scan targeted rebuild demo](https://raw.githubusercontent.com/bugtizen/flutter_rebuild_scan/main/media/rebuild-scan-demo.gif)

The demo shows targeted mode recording rebuild counts, painting widget highlights, and opening the rebuild stats panel. Targeted mode works in debug, profile, and release builds.

## Features

- Real-time overlay highlight for widgets rebuilt in the current frame
- Ranked panel of top rebuilders in a sliding time window
- Runtime controls: clear stats, threshold, highlight mode
- Debug auto-discovery mode for development
- Targeted markers for profile/release diagnostics

## Install

```yaml
dependencies:
  flutter_rebuild_scan: ^0.2.0
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

void main() {
  runApp(
    const RebuildScanApp(
      mode: RebuildScanMode.targeted,
      child: MaterialApp(home: DemoPage()),
    ),
  );
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    RebuildScan.mark(context, name: 'DemoPage');

    return Scaffold(
      body: Center(
        child: Text('Tracked widget'),
      ),
    );
  }
}
```

## Usage modes

- Debug auto mode: `RebuildScanApp(mode: RebuildScanMode.debugAuto)` tracks user-created widgets without markers in debug builds only.
- Targeted mode: `RebuildScanApp(mode: RebuildScanMode.targeted)` with `RebuildScan.mark(context)` tracks selected widgets in debug/profile/release.
- Off mode: `RebuildScanApp(mode: RebuildScanMode.off)` returns the child without installing the overlay.

The example app includes both modes:

```sh
flutter run example
flutter run example --dart-define=REBUILD_SCAN_EXAMPLE_MODE=debugAuto
flutter run --profile example
flutter run --release example
```

Profile/release examples default to targeted mode. `debugAuto` is intentionally debug-only.

## API

- `RebuildScanApp({required Widget child, RebuildScanMode mode = kDebugMode ? RebuildScanMode.debugAuto : RebuildScanMode.off, RebuildScanConfig? config, RebuildScanController? controller})`
- `RebuildScan.mark(BuildContext context, {String? name, Object? tag})`
- `RebuildScanBoundary({required Widget child, String? name, Object? tag, bool enabled = true})`
- `RebuildScanController`: `clearStats`, `setConfig`, `setMode`, `listenable`
- `RebuildScanConfig`: `highlightMode`, `badgeCountMode`, `minRebuildsToShow`, `ignoreTypes`, `showPanel`, `sampleWindow`, `maxEntries`, `trackRects`, `includeFrameworkWidgetsInAutoScan`

## Limitations

- `RebuildScanMode.debugAuto` uses Flutter's debug rebuild hook, so full-widget auto-scan is debug-only.
- Auto mode counts user-created widgets by default and filters Flutter framework internals like `_ActionScope`; set `includeFrameworkWidgetsInAutoScan: true` only for low-level framework debugging.
- `RebuildScan.mark(context)` is for targeted tracking. It is not required for debug auto mode.
- `RebuildScanBoundary` counts the boundary widget build, not every descendant rebuild.
- Profile/release full-widget auto-scan would require build-time instrumentation or Flutter framework changes.
- Rebuild attribution (why it rebuilt) is not provided in this release.
- Rect extraction is best effort; counts still work even when rects are unavailable.

## Performance and mode notes

- `RebuildScanApp` defaults to debug auto in debug and off in profile/release.
- Use `RebuildScanMode.targeted` when you intentionally want profile/release diagnostics.
- Badges show recent-window counts by default. Use `RebuildBadgeCountMode.frame` or `RebuildBadgeCountMode.total` when that better matches your debugging session.
- For lower overhead, set `trackRects: false` when you only need list stats.

## Publish status

- This package is intended for debug diagnostics. Do not enable it in customer-facing release builds unless you explicitly accept the overhead.
