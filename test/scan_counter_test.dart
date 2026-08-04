import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

void main() {
  test('RebuildScanApp defaults to mode-based enablement', () {
    const app = RebuildScanApp(child: SizedBox.shrink());

    expect(
      app.mode,
      kDebugMode ? RebuildScanMode.debugAuto : RebuildScanMode.off,
    );
  });

  test('mode resolver makes debugAuto unsupported outside debug', () {
    expect(
      debugResolveRebuildScanStatus(RebuildScanMode.debugAuto, debugMode: true),
      RebuildScanStatus.active,
    );
    expect(
      debugResolveRebuildScanStatus(
        RebuildScanMode.debugAuto,
        debugMode: false,
      ),
      RebuildScanStatus.debugAutoUnsupported,
    );
    expect(
      debugResolveRebuildScanStatus(RebuildScanMode.targeted, debugMode: false),
      RebuildScanStatus.noTargets,
    );
  });

  test('RebuildScanConfig copies and compares auto-scan framework filter', () {
    const config = RebuildScanConfig();
    final copied = config.copyWith(includeFrameworkWidgetsInAutoScan: true);

    expect(config.includeFrameworkWidgetsInAutoScan, isFalse);
    expect(copied.includeFrameworkWidgetsInAutoScan, isTrue);
    expect(copied, isNot(config));
    expect(
      copied,
      const RebuildScanConfig(includeFrameworkWidgetsInAutoScan: true),
    );
  });

  testWidgets('debugAuto mode counts unwrapped rebuilds in debug', (
    tester,
  ) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );

    final key = GlobalKey<_AutoCounterHostState>();

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.debugAuto,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: MaterialApp(home: AutoCounterHost(key: key)),
      ),
    );

    await tester.pump();

    final initialCount = controller.snapshot.totalRebuilds;
    expect(initialCount, greaterThan(0));

    key.currentState!.increment();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.snapshot.totalRebuilds, greaterThan(initialCount));

    controller.dispose();
  });

  testWidgets('debugAuto mode skips private framework widgets by default', (
    tester,
  ) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.debugAuto,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: const MaterialApp(home: _FrameworkHeavyHost()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final names = controller.snapshot.entriesById.values
        .map((entry) => entry.name ?? entry.widgetType.toString())
        .toSet();

    expect(names, contains('_FrameworkHeavyHost'));
    expect(names, isNot(contains('_ActionScope')));
    expect(names, isNot(contains('_ParentInkResponseProvider')));

    controller.dispose();
  });

  testWidgets('debugAuto mode can opt into framework widgets', (tester) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(
        showPanel: false,
        includeFrameworkWidgetsInAutoScan: true,
      ),
    );

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.debugAuto,
        controller: controller,
        config: const RebuildScanConfig(
          showPanel: false,
          includeFrameworkWidgetsInAutoScan: true,
        ),
        child: const MaterialApp(home: _FrameworkHeavyHost()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final names = controller.snapshot.entriesById.values
        .map((entry) => entry.name ?? entry.widgetType.toString())
        .toSet();

    expect(
      names.where(
        (name) => name.startsWith('_') && name != '_FrameworkHeavyHost',
      ),
      isNotEmpty,
    );

    controller.dispose();
  });

  testWidgets('targeted mode ignores unwrapped rebuilds', (tester) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );

    final key = GlobalKey<_AutoCounterHostState>();

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.targeted,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: MaterialApp(home: AutoCounterHost(key: key)),
      ),
    );

    key.currentState!.increment();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.snapshot.totalRebuilds, 0);

    controller.dispose();
  });

  testWidgets('RebuildScan.mark increments in targeted mode', (tester) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );

    final key = GlobalKey<_MarkedCounterHostState>();

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.targeted,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: MaterialApp(home: MarkedCounterHost(key: key)),
      ),
    );

    await tester.pump();

    final initialCount = controller.snapshot.totalRebuilds;
    expect(initialCount, greaterThan(0));

    key.currentState!.increment();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.snapshot.totalRebuilds, greaterThan(initialCount));

    controller.dispose();
  });

  testWidgets('RebuildScanBoundary counts only its own build', (tester) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );

    final innerTick = ValueNotifier<int>(0);

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.targeted,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: MaterialApp(
          home: RebuildScanBoundary(
            name: 'Boundary',
            child: ValueListenableBuilder<int>(
              valueListenable: innerTick,
              builder: (context, value, _) => Text('tick $value'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final initialCount = controller.snapshot.totalRebuilds;
    expect(initialCount, greaterThan(0));

    innerTick.value += 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.snapshot.totalRebuilds, initialCount);

    innerTick.dispose();
    controller.dispose();
  });

  testWidgets('debugAuto mode preserves an existing rebuild callback', (
    tester,
  ) async {
    var previousCallbackCount = 0;
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (_, _) {
      previousCallbackCount += 1;
    };

    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );
    final key = GlobalKey<_AutoCounterHostState>();

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.debugAuto,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: MaterialApp(home: AutoCounterHost(key: key)),
      ),
    );

    key.currentState!.increment();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(previousCallbackCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(debugOnRebuildDirtyWidget, isNotNull);
    debugOnRebuildDirtyWidget = previousCallback;
    controller.dispose();
  });

  testWidgets('off RebuildScanApp emits no tracking data', (tester) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: false),
    );

    final key = GlobalKey<_CounterHostState>();

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.off,
        controller: controller,
        config: const RebuildScanConfig(showPanel: false),
        child: MaterialApp(home: CounterHost(key: key)),
      ),
    );

    key.currentState!.increment();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.snapshot.totalRebuilds, 0);

    controller.dispose();
  });
}

class CounterHost extends StatefulWidget {
  const CounterHost({super.key});

  @override
  State<CounterHost> createState() => _CounterHostState();
}

class MarkedCounterHost extends StatefulWidget {
  const MarkedCounterHost({super.key});

  @override
  State<MarkedCounterHost> createState() => _MarkedCounterHostState();
}

class AutoCounterHost extends StatefulWidget {
  const AutoCounterHost({super.key});

  @override
  State<AutoCounterHost> createState() => _AutoCounterHostState();
}

class _AutoCounterHostState extends State<AutoCounterHost> {
  int _count = 0;

  void increment() {
    setState(() {
      _count += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('count: $_count')));
  }
}

class _CounterHostState extends State<CounterHost> {
  int _count = 0;

  void increment() {
    setState(() {
      _count += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: RebuildScanBoundary(
          name: 'CounterHostScan',
          child: Text('count: $_count'),
        ),
      ),
    );
  }
}

class _MarkedCounterHostState extends State<MarkedCounterHost> {
  int _count = 0;

  void increment() {
    setState(() {
      _count += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    RebuildScan.mark(context, name: 'MarkedCounterHost');

    return Scaffold(body: Center(child: Text('count: $_count')));
  }
}

class _FrameworkHeavyHost extends StatelessWidget {
  const _FrameworkHeavyHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Actions(
          actions: const <Type, Action<Intent>>{},
          child: TextButton(
            onPressed: () {},
            child: const Text('framework internals'),
          ),
        ),
      ),
    );
  }
}
