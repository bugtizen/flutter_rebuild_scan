import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';
import 'package:flutter_rebuild_scan/src/frame_tracker.dart';
import 'package:flutter_rebuild_scan/src/frame_metrics.dart';
import 'package:flutter_rebuild_scan/src/models.dart';
import 'package:flutter_rebuild_scan/src/registry.dart';
import 'package:flutter_rebuild_scan/src/overlay/painter.dart';

void main() {
  testWidgets('counts-only scanner settles without driving idle frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      const RebuildScanApp(
        mode: RebuildScanMode.targeted,
        config: RebuildScanConfig.performance(),
        child: MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('first paint already has the marked target bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const RebuildScanApp(
        mode: RebuildScanMode.targeted,
        config: RebuildScanConfig(showPanel: false),
        child: MaterialApp(
          home: RebuildScanBoundary(
            name: 'instant',
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );
    final paint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<RebuildScanHighlightPainter>()
        .single;
    expect(paint.snapshot.entriesById.values.single.rect, isNotNull);
    expect(paint.snapshot.entriesById.values.single.totalCount, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('rapid stop-start observes each frame once', (tester) async {
    var calls = 0;
    final tracker = FrameTracker(onFrameEnd: (_) => calls++);
    tracker.start();
    tracker.stop();
    tracker.start();
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(calls, 1);
    tracker.stop();
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(calls, 1);
  });
  testWidgets('flash finishes and idle application settles', (tester) async {
    await tester.pumpWidget(
      const RebuildScanApp(
        mode: RebuildScanMode.targeted,
        config: RebuildScanConfig(showPanel: false),
        child: MaterialApp(
          home: RebuildScanBoundary(child: SizedBox(width: 20, height: 20)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  test('frame counts reset and invalid geometry clears', () {
    final registry = ScanRegistry();
    registry.onRebuild(
      const RebuildEvent(
        id: 1,
        widgetType: SizedBox,
        frame: 1,
        micros: 1000,
        rect: Rect.fromLTWH(0, 0, 10, 10),
      ),
      const Duration(seconds: 1),
    );
    registry.currentFrame = 2;
    registry.updateRect(1, rect: null);
    final entry = registry.snapshotEntries(
      window: const Duration(seconds: 1),
      nowMicros: 2000,
    )[1]!;
    expect(entry.frameCount, 0);
    expect(entry.rect, isNull);
  });
  test('engine throughput uses timestamps, budgets adapt to refresh rate', () {
    final metrics = FrameMetricsCollector();
    FrameTiming timing(int start, int number) => FrameTiming(
      vsyncStart: start,
      buildStart: start,
      buildFinish: start + 9000,
      rasterStart: start + 9000,
      rasterFinish: start + 10000,
      rasterFinishWallTime: 0,
      frameNumber: number,
    );
    metrics.add([timing(0, 1), timing(16667, 2)]);
    expect(metrics.snapshot(60).framesPerSecond, closeTo(60, .01));
    expect(metrics.snapshot(60).overBudgetFrames, 0);
    expect(metrics.snapshot(120).overBudgetFrames, 2);
    expect(metrics.snapshot(120).completedFrames, 2);
    metrics.clear();
    expect(metrics.snapshot(60).completedFrames, 0);
  });
}
