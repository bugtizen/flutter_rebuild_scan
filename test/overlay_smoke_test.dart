import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';
import 'package:flutter_rebuild_scan/src/overlay/panel.dart';

void main() {
  testWidgets('overlay mounts and unmounts without errors', (tester) async {
    await tester.pumpWidget(
      const RebuildScanApp(
        mode: RebuildScanMode.targeted,
        config: RebuildScanConfig(showPanel: true),
        child: MaterialApp(
          home: Scaffold(
            body: RebuildScanBoundary(name: 'SmokeScan', child: Text('smoke')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('highlight mode control changes without Navigator', (
    tester,
  ) async {
    final controller = RebuildScanController(
      config: const RebuildScanConfig(showPanel: true),
    );

    await tester.pumpWidget(
      RebuildScanApp(
        mode: RebuildScanMode.targeted,
        controller: controller,
        config: const RebuildScanConfig(showPanel: true),
        child: const MaterialApp(
          home: Scaffold(
            body: RebuildScanBoundary(name: 'SmokeScan', child: Text('smoke')),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pump();
    await tester.tap(find.text('heatmap'));
    await tester.pump();

    expect(controller.snapshot.config.highlightMode, HighlightMode.heatmap);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('targeted panel explains missing marks', (tester) async {
    await tester.pumpWidget(
      const RebuildScanApp(
        mode: RebuildScanMode.targeted,
        config: RebuildScanConfig(showPanel: true),
        child: MaterialApp(home: Scaffold(body: Text('plain'))),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pump();

    expect(
      find.textContaining('Add RebuildScan.mark(context)'),
      findsOneWidget,
    );
  });

  testWidgets('panel explains unsupported debug auto mode', (tester) async {
    final controller =
        RebuildScanController(config: const RebuildScanConfig(showPanel: true))
          ..setMode(
            mode: RebuildScanMode.debugAuto,
            status: RebuildScanStatus.debugAutoUnsupported,
          );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              ScanPanelPage(
                controller: controller,
                snapshot: controller.snapshot,
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('debug-only'), findsOneWidget);

    controller.dispose();
  });

  testWidgets(
    'disposing a tracked widget before rect callback does not crash',
    (tester) async {
      final toggleKey = GlobalKey<_ToggleHostState>();

      await tester.pumpWidget(
        RebuildScanApp(
          mode: RebuildScanMode.targeted,
          config: const RebuildScanConfig(showPanel: false),
          child: MaterialApp(home: ToggleHost(key: toggleKey)),
        ),
      );

      expect(toggleKey.currentState, isNotNull);
      toggleKey.currentState?.hideTrackedWidget();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.takeException(), isNull);
    },
  );
}

class ToggleHost extends StatefulWidget {
  const ToggleHost({super.key});

  @override
  State<ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<ToggleHost> {
  bool _showTrackedWidget = true;

  void hideTrackedWidget() {
    setState(() {
      _showTrackedWidget = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showTrackedWidget
          ? const RebuildScanBoundary(
              name: 'TransientScan',
              child: SizedBox(width: 24, height: 24),
            )
          : const SizedBox.shrink(),
    );
  }
}
