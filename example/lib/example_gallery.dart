import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

import 'examples/counters.dart';
import 'examples/activity.dart';
import 'examples/mock_feed.dart';
import 'examples/hero.dart';
import 'examples/login.dart';
import 'examples/feed.dart';

class ExampleCase {
  const ExampleCase(
    this.id,
    this.title,
    this.description,
    this.expectation,
    this.code,
    this.builder, {
    this.config = const RebuildScanConfig(),
    this.mode = RebuildScanMode.targeted,
  });
  final String id, title, description, expectation, code;
  final Widget Function(RebuildScanController) builder;
  final RebuildScanConfig config;
  final RebuildScanMode mode;
}

final exampleCases = <ExampleCase>[
  ExampleCase(
    'login',
    'Login form',
    'Track independent email and password field updates in a familiar form.',
    'Type into each field, reveal the password, then try local sign-in validation. Each field is observed separately, so typing in email does not mark password.',
    """ValueListenableBuilder<TextEditingValue>(
  valueListenable: controller,
  builder: (context, value, child) {
    RebuildScan.mark(context, name: 'Login email');
    return TextField(controller: controller);
  },
)""",
    (_) => const LoginExample(),
  ),
  ExampleCase(
    'targeted',
    'Targeted counter',
    'Track one widget you own.',
    'Tap Increment. Only the small counter records a build. Build counts include the initial render; Value counts taps. Change the badge source to compare recent, current-frame and total counts.',
    "RebuildScan.mark(context, name: 'Counter');\n// Call inside the build method of the widget to measure.",
    (controller) => TargetedExample(controller: controller),
  ),
  ExampleCase(
    'boundary',
    'Boundary vs descendants',
    'Wrap a widget without editing its implementation.',
    'Incrementing the child does not rebuild its boundary. Refreshing the boundary does. A boundary does not count descendant builds.',
    "RebuildScanBoundary(\n  name: 'Third-party component',\n  child: MyComponent(),\n)",
    (_) => const BoundaryExample(),
  ),
  ExampleCase(
    'list',
    'Selectable feed & Hero detail',
    'Browse a mock news feed, save individual rows, filter by topic and open story details.',
    'The feed uses ListView.builder with stable story keys. Save a row to see the selected count change; sibling row elements keep their own state. Tap a story to transition its image into the detail page with a Hero.',
    """ListView.builder(
  itemCount: stories.length,
  itemBuilder: (context, index) {
    final story = stories[index];
    return FeedRow(key: ValueKey(story.id), story: story);
  },
)""",
    (_) => const FeedExample(),
  ),
  ExampleCase(
    'heatmap',
    'Rebuild heatmap',
    'Compare steady activity with a fixed color scale.',
    'Start the mock updates: Slow updates twice/sec; Fast updates ten times/sec. The scale stays at 0–10 builds/sec. Activity is not a measurement of rendering cost.',
    'RebuildScanConfig(\n  highlightMode: HighlightMode.heatmap,\n  heatmapMaxRebuildsPerSecond: 10,\n)',
    (_) => const HeatmapExample(),
    config: const RebuildScanConfig(
      highlightMode: HighlightMode.heatmap,
      heatmapMaxRebuildsPerSecond: 10,
    ),
  ),
  ExampleCase(
    'feed',
    'Mock live feed · 1,000/sec',
    'Compare direct notifications with frame coalescing.',
    'Start the local mock feed. Each 10 ms tick creates 10 inputs. Compare inputs, display notifications and builds; 1,000 inputs/sec does not mean 1,000 rendered frames/sec.',
    '// Keep receiving all inputs, but display the latest once per frame.\npending ??= SchedulerBinding.instance.scheduleFrameCallback((_) {\n  pending = null;\n  display.value = latest;\n});',
    (_) => const MockFeedExample(),
    config: const RebuildScanConfig.performance(),
  ),
  ExampleCase(
    'frames',
    'Engine frame monitor',
    'Measure frame timings without widget rectangles.',
    'Start the small animation. Read engine frames and UI/raster p95 in the monitor. Enable the native graph if useful. Profile on a physical device for representative timings; the animation is not intended to cause jank.',
    'RebuildScanApp(\n  mode: RebuildScanMode.targeted,\n  config: const RebuildScanConfig.performance(),\n  child: MyApp(),\n)',
    (controller) => FrameMonitorExample(controller: controller),
    config: const RebuildScanConfig.performance(),
  ),
  ExampleCase(
    'controls',
    'Filters & runtime controls',
    'Reduce visual noise and clear a measurement session.',
    'Both counters work, but the ignored type is not recorded. Toggle its filter, switch flash/outline/heatmap, set a threshold, and clear the session using the public controller API.',
    'controller.setConfig(controller.config.copyWith(\n  ignoreTypes: {IgnoredCounter},\n));\ncontroller.clearStats();',
    (controller) => ControlsExample(controller: controller),
    config: const RebuildScanConfig(ignoreTypes: {IgnoredCounter}),
  ),
  ExampleCase(
    'auto',
    'Debug auto-scan',
    'Discover user widgets without explicit markers.',
    'Increment the unmarked counter and look for highlights. Auto-scan works only in debug. Profile/release show an explanation instead of pretending to capture builds.',
    'RebuildScanApp(\n  mode: RebuildScanMode.debugAuto,\n  child: MyApp(),\n)',
    (_) => const AutoScanExample(),
    mode: RebuildScanMode.debugAuto,
  ),
  ExampleCase(
    'hero',
    'Hero navigation',
    'See how a tracked feed image transitions into its detail page.',
    'The selectable feed case shows Hero navigation with realistic list items. This focused demo shows how to scope a nested navigator. Geometry may be skipped while a Hero is in flight; counts are separate from rectangle availability.',
    "// Keep the navigator being inspected inside the scanner.\nRebuildScanApp(\n  mode: RebuildScanMode.targeted,\n  child: Navigator(/* routes with matching Hero tags */),\n)",
    (_) => const HeroExample(),
  ),
  ExampleCase(
    'off',
    'Scanner off',
    'Keep the app interactive without installing diagnostics.',
    'Increment still works, but there is no scanner panel, highlight or timing subscription. Off is the package default in profile/release unless you explicitly enable diagnostics.',
    'RebuildScanApp(\n  mode: RebuildScanMode.off,\n  child: MyApp(),\n)',
    (_) => const CounterTile(name: 'Untracked counter'),
    mode: RebuildScanMode.off,
  ),
];

class ExampleGallery extends StatelessWidget {
  const ExampleGallery({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rebuild Scan examples')),
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Start with familiar screens: a local login form and a selectable feed that opens story details. Then explore focused scanner features. All data is mocked locally.',
          ),
        ),
        for (final example in exampleCases)
          ListTile(
            key: ValueKey('case-${example.id}'),
            title: Text(example.title),
            subtitle: Text(example.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ExamplePage(example: example),
              ),
            ),
          ),
      ],
    ),
  );
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key, required this.example});
  final ExampleCase example;
  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final controller = RebuildScanController(config: widget.example.config);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final example = widget.example;
    return Scaffold(
      appBar: AppBar(title: Text(example.title)),
      body: RebuildScanApp(
        mode: example.mode,
        controller: controller,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            example.config.showFrameMonitor ? 96 : 16,
            16,
            96,
          ),
          children: [
            Text(
              example.description,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(example.expectation),
            const SizedBox(height: 16),
            if (example.mode == RebuildScanMode.debugAuto && !kDebugMode)
              const Text(
                'Auto-scan is debug-only. Run flutter run, or choose Targeted counter for profile diagnostics.',
              )
            else
              example.builder(controller),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Integration code'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      example.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'For highlights, tap the scanner button to open ranked stats and controls. Frame monitoring uses the performance preset with rectangle tracking disabled.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
