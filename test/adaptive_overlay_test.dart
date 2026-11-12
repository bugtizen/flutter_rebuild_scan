import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';
import 'package:flutter_rebuild_scan/src/utils/rect_utils.dart';
import 'package:flutter_rebuild_scan/src/utils/visual_refresh.dart';

void main() {
  test('visual refresh backs off and recovers with hysteresis', () {
    final policy = VisualRefresh();
    expect(policy.intervalMicros, 16667);
    policy.record(1001, 0);
    expect(policy.intervalMicros, 33334);
    policy.record(1001, 1);
    expect(policy.intervalMicros, 66667);
    policy.record(100, 2);
    policy.record(100, 999999);
    expect(policy.intervalMicros, 66667);
    policy.record(100, 1000002);
    expect(policy.intervalMicros, 33334);
    policy.record(100, 2000002);
    expect(policy.intervalMicros, 16667);
  });

  testWidgets('burst counts stay exact with one paint notification', (
    tester,
  ) async {
    final controller = RebuildScanController(
      mode: RebuildScanMode.targeted,
      status: RebuildScanStatus.active,
    );
    controller.attach();
    await tester.pumpWidget(const SizedBox(key: ValueKey('target')));
    final element = tester.element(find.byKey(const ValueKey('target')));
    var notifications = 0;
    controller.repaint.addListener(() => notifications++);
    for (var i = 0; i < 1000; i++) {
      controller.recordRebuild(id: 1, widgetType: SizedBox);
      controller.queueRectMeasurement(id: 1, element: element);
    }
    expect(notifications, 1);
    expect(controller.pendingRectMeasurementCount, 1);
    final entry = controller.captureSnapshot().entriesById[1]!;
    expect(entry.totalCount, 1000);
    expect(entry.recentCount, 1000);
    expect(entry.frameCount, 1000);
    controller.recordVisualCost(2000);
    controller.recordVisualCost(2000);
    for (var i = 0; i < 1000; i++) {
      controller.recordRebuild(id: 1, widgetType: SizedBox);
    }
    expect(controller.snapshot.entriesById[1]!.totalCount, 2000);
    controller.dispose();
  });

  testWidgets('ignored boundary never enters geometry queue', (tester) async {
    final controller = RebuildScanController();
    await tester.pumpWidget(
      RebuildScanApp(
        controller: controller,
        mode: RebuildScanMode.targeted,
        config: const RebuildScanConfig(ignoreTypes: {SizedBox}),
        child: const MaterialApp(home: RebuildScanBoundary(child: SizedBox())),
      ),
    );
    expect(controller.snapshot.totalRebuilds, 0);
    expect(controller.visualSnapshot().entriesById, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'shared geometry matches Flutter after transform and clipping changes',
    (tester) async {
      final offset = ValueNotifier(Offset.zero);
      const target = SizedBox(key: ValueKey('geometry'), width: 80, height: 80);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ClipRect(
              child: SizedBox(
                width: 50,
                height: 50,
                child: ValueListenableBuilder<Offset>(
                  valueListenable: offset,
                  child: target,
                  builder: (_, value, child) => Transform.translate(
                    offset: value,
                    child: OverflowBox(
                      maxWidth: 80,
                      maxHeight: 80,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final element = tester.element(find.byKey(const ValueKey('geometry')));
      expect(
        RectMeasurementPass().measure(element),
        RectUtils.getGlobalRect(element),
      );
      offset.value = const Offset(20, 10);
      await tester.pump();
      expect(
        RectMeasurementPass().measure(element),
        RectUtils.getGlobalRect(element),
      );
      await tester.pumpWidget(const SizedBox());
      expect(RectMeasurementPass().measure(element), isNull);
      offset.dispose();
    },
  );
}
