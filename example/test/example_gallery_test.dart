import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';
import 'package:flutter_rebuild_scan_example/main.dart';
import 'package:flutter_rebuild_scan_example/example_gallery.dart';

Future<void> openCase(WidgetTester tester, String id) async {
  final tile = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(
    tile,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('every case opens and returns without active work', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const ExamplesApp());
    for (final example in exampleCases) {
      await openCase(tester, example.id);
      expect(find.text(example.title), findsOneWidget);
      expect(tester.takeException(), isNull, reason: example.id);
      Navigator.of(tester.element(find.byType(ExamplePage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ExampleGallery), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('login field updates stay isolated and validation is local', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const ExamplesApp());
    await openCase(tester, 'login');
    final controller = tester
        .widget<RebuildScanApp>(find.byType(RebuildScanApp))
        .controller!;
    await tester.enterText(
      find.byKey(const ValueKey('login-email-input')),
      'dev@example.com',
    );
    await tester.pump();
    var counts = {
      for (final e in controller.snapshot.entriesById.values)
        e.name: e.totalCount,
    };
    expect(counts['Login email'], greaterThan(1));
    expect(counts['Login password'], 1);
    await tester.enterText(
      find.byKey(const ValueKey('login-password-input')),
      'secret123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(
      find.textContaining('Signed in locally as dev@example.com'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('feed selection is local and story opens a Hero detail', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const ExamplesApp());
    await openCase(tester, 'list');
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(
      find.text('1 saved · tap a story to open its detail'),
      findsOneWidget,
    );
    await tester.tap(find.text('Building smoother scrolling feeds'));
    await tester.pumpAndSettle();
    expect(find.text('Story'), findsOneWidget);
    expect(find.textContaining('smoother scrolling feeds'), findsOneWidget);
    Navigator.of(tester.element(find.text('Story'))).pop();
    await tester.pumpAndSettle();
    expect(
      find.text('1 saved · tap a story to open its detail'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('mock feed starts, pauses and cancels on exit', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const ExamplesApp());
    await openCase(tester, 'feed');
    expect(find.textContaining('Inputs: 0'), findsOneWidget);
    await tester.tap(find.text('Start mock feed'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.textContaining('Inputs: 100\n'), findsOneWidget);
    await tester.tap(find.text('Pause mock feed'));
    await tester.pump();
    final paused = tester
        .widget<Text>(find.byKey(const ValueKey('feed-summary')))
        .data;
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('feed-summary'))).data,
      paused,
    );
    await tester.tap(find.text('Start mock feed'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('leaving running activity pages disposes their work', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const ExamplesApp());
    for (final entry in {
      'heatmap': 'Start mock updates',
      'frames': 'Start animation',
    }.entries) {
      await openCase(tester, entry.key);
      await tester.ensureVisible(find.text(entry.value));
      await tester.tap(find.text(entry.value));
      await tester.pump(const Duration(milliseconds: 200));
      Navigator.of(tester.element(find.byType(ExamplePage))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('Hero transitions do not raise rendering errors', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const ExamplesApp());
    await openCase(tester, 'hero');
    await tester.ensureVisible(find.text('Open Hero detail'));
    await tester.tap(find.text('Open Hero detail'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Back to small Hero'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Open Hero detail'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
