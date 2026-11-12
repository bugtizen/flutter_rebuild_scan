import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';
import 'counters.dart';

class HeatmapExample extends StatefulWidget {
  const HeatmapExample({super.key});
  @override
  State<HeatmapExample> createState() => _HeatmapExampleState();
}

class _HeatmapExampleState extends State<HeatmapExample> {
  final slow = ValueNotifier(0), fast = ValueNotifier(0);
  Timer? timer;
  int ticks = 0;
  void stop() {
    timer?.cancel();
    timer = null;
  }

  void toggle() {
    setState(() {
      if (timer != null) {
        stop();
        return;
      }
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        fast.value++;
        if (++ticks % 5 == 0) slow.value++;
      });
    });
  }

  @override
  void dispose() {
    stop();
    slow.dispose();
    fast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FilledButton(
        onPressed: toggle,
        child: Text(
          timer == null ? 'Start mock updates' : 'Pause mock updates',
        ),
      ),
      _rateTile('Slow · 2/sec', slow),
      _rateTile('Fast · 10/sec', fast),
    ],
  );
  Widget _rateTile(String label, ValueNotifier<int> value) =>
      ValueListenableBuilder<int>(
        valueListenable: value,
        builder: (context, count, child) {
          RebuildScan.mark(context, name: label);
          return Card(
            child: ListTile(
              title: Text(label),
              subtitle: Text('Updates: $count'),
            ),
          );
        },
      );
}

class FrameMonitorExample extends StatefulWidget {
  const FrameMonitorExample({super.key, required this.controller});
  final RebuildScanController controller;
  @override
  State<FrameMonitorExample> createState() => _FrameMonitorExampleState();
}

class _FrameMonitorExampleState extends State<FrameMonitorExample>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  bool running = false;
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 90,
        child: Center(
          child: RotationTransition(
            turns: animation,
            child: const Icon(Icons.sync, size: 56, color: Colors.teal),
          ),
        ),
      ),
      FilledButton(
        onPressed: () => setState(() {
          running = !running;
          if (running) {
            animation.repeat();
          } else {
            animation.stop();
          }
        }),
        child: Text(running ? 'Pause animation' : 'Start animation'),
      ),
      ValueListenableBuilder<int>(
        valueListenable: widget.controller.settingsRevision,
        builder: (context, _, child) => SwitchListTile(
          title: const Text('Show native timing graphs'),
          value: widget.controller.config.showPerformanceOverlay,
          onChanged: (value) => widget.controller.setConfig(
            widget.controller.config.copyWith(showPerformanceOverlay: value),
          ),
        ),
      ),
      ValueListenableBuilder<FrameMetricsSnapshot>(
        valueListenable: widget.controller.frameMetrics,
        builder: (context, metrics, child) => Text(
          'Last active sample\nEngine frames: ${metrics.completedFrames}\n'
          'Frame budget: ${(1000 / metrics.refreshRate).toStringAsFixed(2)} ms\n'
          'UI p95: ${(metrics.uiP95.inMicroseconds / 1000).toStringAsFixed(2)} ms\n'
          'Raster p95: ${(metrics.rasterP95.inMicroseconds / 1000).toStringAsFixed(2)} ms\n'
          'Over-budget frames: ${metrics.overBudgetFrames}',
        ),
      ),
    ],
  );
}

class AutoScanExample extends StatelessWidget {
  const AutoScanExample({super.key});
  @override
  Widget build(BuildContext context) =>
      const CounterTile(name: 'Unmarked counter', mark: false);
}
