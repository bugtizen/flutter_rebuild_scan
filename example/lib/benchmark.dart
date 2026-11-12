// Run with: flutter run -t lib/benchmark.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

void main() => runApp(const ScannerBenchmark());

/// Device benchmark: the same workload with automatic counters enabled and off.
class ScannerBenchmark extends StatefulWidget {
  const ScannerBenchmark({super.key});
  @override
  State<ScannerBenchmark> createState() => _ScannerBenchmarkState();
}

class _ScannerBenchmarkState extends State<ScannerBenchmark> {
  final cells = List.generate(2000, (_) => ValueNotifier(0));
  final timings = <FrameTiming>[];
  Timer? input;
  bool running = false;
  bool collecting = false;
  RebuildScanMode mode = RebuildScanMode.off;
  String status = 'Run on a physical device. Results print as JSON.';
  int builds = 0;
  int cursor = 0;

  void onTimings(List<FrameTiming> batch) {
    if (collecting) timings.addAll(batch);
  }

  Future<void> measure() async {
    if (running) return;
    setState(() {
      running = true;
    });
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    input = Timer.periodic(const Duration(milliseconds: 10), (_) {
      for (var i = 0; i < 10; i++) {
        cells[cursor++ % 100].value++;
      }
    });
    try {
      final enabledMode = kDebugMode
          ? RebuildScanMode.debugAuto
          : RebuildScanMode.targeted;
      for (var repeat = 0; repeat < 3; repeat++) {
        // Alternate order to reduce warm-up and thermal bias.
        final modes = repeat.isEven
            ? [RebuildScanMode.off, enabledMode]
            : [enabledMode, RebuildScanMode.off];
        for (final next in modes) {
          if (!mounted) return;
          setState(() {
            mode = next;
            status = '${next.name}: warming up';
          });
          await Future<void>.delayed(const Duration(seconds: 10));
          if (!mounted) return;
          timings.clear();
          final initialBuilds = builds;
          collecting = true;
          final clock = Stopwatch()..start();
          await Future<void>.delayed(const Duration(seconds: 30));
          collecting = false;
          if (!mounted) return;
          final ui = timings.map((t) => t.buildDuration.inMicroseconds).toList()
            ..sort();
          final raster =
              timings.map((t) => t.rasterDuration.inMicroseconds).toList()
                ..sort();
          final hz = View.of(context).display.refreshRate;
          int percentile(List<int> values, double fraction) => values.isEmpty
              ? 0
              : values[(values.length * fraction).ceil() - 1];
          final result = jsonEncode({
            'mode': next.name,
            'repeat': repeat,
            'refreshHz': hz,
            'frames': timings.length,
            'builds': builds - initialBuilds,
            'elapsedMicros': clock.elapsedMicroseconds,
            'uiP95Micros': percentile(ui, .95),
            'uiP99Micros': percentile(ui, .99),
            'rasterP95Micros': percentile(raster, .95),
            'overBudgetFrames': timings
                .where(
                  (t) =>
                      t.buildDuration.inMicroseconds > 1000000 / hz ||
                      t.rasterDuration.inMicroseconds > 1000000 / hz,
                )
                .length,
          });
          debugPrint(result);
          setState(() {
            status = result;
          });
        }
      }
    } finally {
      input?.cancel();
      collecting = false;
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
      if (mounted) {
        setState(() {
          running = false;
        });
      }
    }
  }

  @override
  void dispose() {
    input?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    for (final cell in cells) {
      cell.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RebuildScanApp(
    mode: mode,
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('2,000 targets · 100 active badges')),
        body: Column(
          children: [
            FilledButton(
              onPressed: running ? null : measure,
              child: const Text('Run comparison (~4 minutes)'),
            ),
            Text(status),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  children: [
                    for (final cell in cells)
                      _Cell(value: cell, onBuild: () => builds++),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.onBuild});
  final ValueNotifier<int> value;
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: value,
    builder: (context, count, _) {
      onBuild();
      RebuildScan.mark(context);
      Widget result = SizedBox(width: 24, height: 24, child: Text('$count'));
      for (var i = 0; i < 8; i++) {
        result = ClipRect(
          child: Padding(padding: EdgeInsets.zero, child: result),
        );
      }
      return result;
    },
  );
}
