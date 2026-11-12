# flutter_rebuild_scan

`flutter_rebuild_scan` is a rebuild scanner for Flutter apps.
It highlights rebuilt widgets in real time and shows top rebuilders in a draggable debug panel.

## Demo

The [example gallery](example/lib/main.dart) opens with a list of eleven common use
cases. Tap a case for a small interactive demo, an explanation, and integration
code. Everything runs locally, including the mock 1,000-inputs/sec feed.
See the [example guide](example/README.md).

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

Run the gallery without a server or environment variables:

```sh
cd example
flutter run
# For representative device frame timings:
flutter run --profile
```

Login, selectable feed/detail, targeted counter, boundary, heatmap, mock live feed, frame monitor,
filters/controls, Hero navigation and off mode work in profile/release too.
Debug auto-scan has an explicit debug-only explanation in other build modes.

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

## Profile monitoring and high-rate inputs

For Android/iOS diagnostics with minimal visual work:

```dart
RebuildScanApp(
  mode: RebuildScanMode.targeted,
  config: const RebuildScanConfig.performance(),
  child: MyApp(),
)
```

The performance preset collects Flutter engine timings and shows a compact HUD,
without measuring widget rectangles. Existing `RebuildScan.mark` calls still count
builds. Engine metrics include completed frames, observed frames/sec, UI/raster
p95 and p99, maxima, budget overruns, and pipeline latency overruns. Read them from
`controller.frameMetrics`. Timing reports are batched by Flutter (approximately
100 ms in profile, one second in release). The HUD retains the last active sample
when idle; these are engine measurements, not OS presentation guarantees.

Aggregate listeners publish on existing application frames, at most every
`statsInterval` (250 ms by default). Reading `controller.snapshot` or calling
`captureSnapshot()` explicitly builds a fresh full snapshot. Highlight painting
uses live, capped state independently. Counters use exact rolling timestamps;
retained history scales with rebuild rate within `sampleWindow`, capped by
`maxEntries` targets. Visuals show the most recently rebuilt `maxHighlights`
targets (100 by default); other targets remain counted in the panel.

Heatmap colors use a fixed scale: `recentCount / sampleWindow` in builds/sec,
divided by `heatmapMaxRebuildsPerSecond` (60 by default). Red means high activity,
not proof that a widget is slow. `targetRefreshRate` overrides the display-derived
frame budget. `showPerformanceOverlay` enables Flutter's engine-rendered graphs.

Explore the **Mock live feed · 1,000/sec** gallery page to compare direct state
notifications with frame coalescing. It generates ten logical inputs every 10 ms;
this is a mock target rate, not a timing guarantee. Inputs, notifications, builds
and completed engine frames are distinct counts. All activity starts on demand
and is stopped when its page is disposed.

For performance comparisons, use profile builds on physical 60/120 Hz Android/iOS
devices. Warm up 10 seconds, measure 30 seconds three times, then check retained
memory over 10 minutes. Initial targets versus scanner-off are <=0.25 ms additional
UI p95 for counters-only, <=1 ms for 100 highlights, and <=1 percentage point
additional budget overruns. These require device measurements; widget tests
cannot establish them. Minimum Flutter: 3.38.5.
