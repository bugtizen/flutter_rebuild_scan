# Rebuild Scan example gallery

Run the app, select a common screen, and follow its short explanation. Every case shows
integration code and provides an interactive example. No backend, WebSocket
server, environment variables, or extra packages are needed.

```sh
flutter pub get
flutter run
```

Run from this `example` directory. Use `flutter run --profile` on a physical device
when comparing frame timings. Debug auto-scan is intentionally debug-only; its
page explains this when running in profile/release.

## Cases

The gallery presents **11 cases** built around common screens plus focused feature examples:

| Page | Typical use | Efficient pattern |
| --- | --- | --- |
| Login form | Email/password forms | Track each field separately; typing in email should not count password builds. |
| Selectable feed & Hero detail | News, shopping, message feeds | Build rows lazily with `ListView.builder`, select individual saved stories, and tap a story to open its Hero detail. |
| Targeted counter | A widget you own | Mark only the widget you need; compare badge count sources. |
| Boundary vs descendants | Third-party components | Wrap the component; understand that child rebuilds are not boundary builds. |
| Rebuild heatmap | Spot frequently updated widgets | Use a fixed builds/sec scale; frequency is not rendering cost. |
| Mock live feed · 1,000/sec | Live prices, chat, sensors | Receive every input; publish the latest display state once per frame. |
| Engine frame monitor | Profile diagnostics | Use the performance preset without rectangle measurement; optionally enable native graphs. |
| Filters & runtime controls | Noisy screens and repeated investigations | Ignore known types, set a threshold, change highlight style, clear the session. |
| Debug auto-scan | Discover unexpected rebuilds | No marks needed; use targeted mode for profile/release. |
| Hero navigation | Animated route changes | Keep the inspected navigator inside the scanner; skip unavailable geometry. |
| Scanner off | Normal application use | Disable instrumentation while the application remains interactive. |

Mock activity is paused initially. Tap Start to run it, Pause to stop, or leave
the page to dispose its timer/animation and pending frame callback. The feed uses
ten logical inputs per 10 ms timer tick: 1,000/sec is its target, not a promise
about device timer precision. Notifications, widget builds and engine frames are
separate measurements. The mock feed does not measure networking or JSON parsing.

The scanner button opens ranked statistics and controls. The engine monitor shows
last-active measurements because timings arrive in batches; it does not render
new frames just to update an idle counter. The performance preset disables
highlights and rectangle measurements.

## Source map

- `lib/main.dart`: app entry point and interactive gallery preview.
- `lib/example_gallery.dart`: case catalog, navigation, explanations and snippets.
- `lib/examples/counters.dart`: targeted marks, boundaries, rows and controls.
- `lib/examples/login.dart`: isolated login fields and local validation.
- `lib/examples/feed.dart`: selectable `ListView.builder` rows and Hero story details.
- `lib/examples/activity.dart`: heatmap, animation/frame monitoring and auto-scan.
- `lib/examples/mock_feed.dart`: local feed and frame coalescing.
- `lib/examples/hero.dart`: nested Hero navigation.

```sh
flutter test
flutter analyze
```

Tests cover gallery navigation, row isolation, mock activity cleanup and Hero
push/pop rendering. They do not replace physical-device performance profiling.
