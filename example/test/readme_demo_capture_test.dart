import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';
import 'package:flutter_rebuild_scan_example/main.dart';

void main() {
  setUpAll(() async {
    final fontFile = _findReadableFontFile();
    if (fontFile == null) {
      return;
    }

    final loader = FontLoader('Roboto')..addFont(_loadFontData(fontFile));
    await loader.load();
  });

  testWidgets('captures README demo frames', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final outputDirectory = Directory('build/readme_demo_frames');
    if (outputDirectory.existsSync()) {
      outputDirectory.deleteSync(recursive: true);
    }
    outputDirectory.createSync(recursive: true);

    final captureKey = GlobalKey();
    var frame = 0;

    Future<void> captureFrame() async {
      await tester.pump(const Duration(milliseconds: 80));
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final bytes =
          await tester.runAsync<ByteData>(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            return bytes!;
          }) ??
          (throw StateError('Failed to encode demo frame.'));

      final path =
          '${outputDirectory.path}/frame_${frame.toString().padLeft(3, '0')}.png';
      await tester.runAsync<void>(() {
        return File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      });
      frame += 1;
    }

    Future<void> captureHold(int count) async {
      for (var i = 0; i < count; i += 1) {
        await captureFrame();
      }
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: const RebuildScanApp(
          mode: RebuildScanMode.targeted,
          config: RebuildScanConfig(
            showPanel: true,
            highlightMode: HighlightMode.flash,
            badgeCountMode: RebuildBadgeCountMode.recent,
            sampleWindow: Duration(seconds: 2),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RebuildDemoPage(
              title: 'Targeted Rebuild Demo',
              markTargets: true,
            ),
          ),
        ),
      ),
    );

    await captureHold(4);

    await tester.tap(find.text('Burst +5 tick'));
    await captureHold(5);

    await tester.tap(find.widgetWithText(ListTile, 'Row 2'));
    await captureHold(5);

    await tester.tap(find.byType(Switch));
    await captureHold(5);

    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await captureHold(8);
  });
}

File? _findReadableFontFile() {
  const paths = <String>[
    '/System/Library/Fonts/Geneva.ttf',
    '/System/Library/Fonts/SFNSMono.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  ];

  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }

  return null;
}

Future<ByteData> _loadFontData(File fontFile) async {
  final bytes = await fontFile.readAsBytes();
  return ByteData.sublistView(bytes);
}
