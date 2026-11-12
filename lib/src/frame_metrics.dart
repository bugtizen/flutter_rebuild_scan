// ignore_for_file: public_member_api_docs
import 'dart:ui';
import 'package:flutter/foundation.dart';

@immutable
class FrameMetricsSnapshot {
  const FrameMetricsSnapshot({
    this.completedFrames = 0,
    this.engineFrameNumber,
    this.framesPerSecond,
    this.uiP95 = Duration.zero,
    this.rasterP95 = Duration.zero,
    this.uiP99 = Duration.zero,
    this.rasterP99 = Duration.zero,
    this.uiMax = Duration.zero,
    this.rasterMax = Duration.zero,
    this.overBudgetFrames = 0,
    this.highLatencyFrames = 0,
    this.refreshRate = 60,
  });
  final int completedFrames;
  final int? engineFrameNumber;
  final double? framesPerSecond;
  final Duration uiP95, rasterP95, uiP99, rasterP99, uiMax, rasterMax;
  final int overBudgetFrames, highLatencyFrames;
  final double refreshRate;
}

class FrameMetricsCollector {
  final List<FrameTiming> samples = [];
  int count = 0;
  void clear() {
    samples.clear();
    count = 0;
  }

  void add(List<FrameTiming> batch) {
    count += batch.length;
    samples.addAll(batch);
    if (samples.isEmpty) return;
    final cutoff =
        samples.last.timestampInMicroseconds(FramePhase.rasterFinish) - 1000000;
    samples.removeWhere(
      (t) => t.timestampInMicroseconds(FramePhase.rasterFinish) < cutoff,
    );
    if (samples.length > 512) samples.removeRange(0, samples.length - 512);
  }

  FrameMetricsSnapshot snapshot(double hz) {
    if (samples.isEmpty) return FrameMetricsSnapshot(refreshRate: hz);
    final ui = samples.map((t) => t.buildDuration.inMicroseconds).toList()
      ..sort();
    final raster = samples.map((t) => t.rasterDuration.inMicroseconds).toList()
      ..sort();
    Duration p(List<int> a, double n) =>
        Duration(microseconds: a[(a.length * n).ceil() - 1]);
    final span =
        samples.last.timestampInMicroseconds(FramePhase.rasterFinish) -
        samples.first.timestampInMicroseconds(FramePhase.rasterFinish);
    return FrameMetricsSnapshot(
      completedFrames: count,
      engineFrameNumber: samples.last.frameNumber < 0
          ? null
          : samples.last.frameNumber,
      framesPerSecond: span > 0 ? (samples.length - 1) * 1000000 / span : null,
      uiP95: p(ui, .95),
      uiP99: p(ui, .99),
      rasterP95: p(raster, .95),
      rasterP99: p(raster, .99),
      uiMax: p(ui, 1),
      rasterMax: p(raster, 1),
      refreshRate: hz,
      overBudgetFrames: samples
          .where(
            (t) =>
                t.buildDuration.inMicroseconds > 1000000 / hz ||
                t.rasterDuration.inMicroseconds > 1000000 / hz,
          )
          .length,
      highLatencyFrames: samples
          .where((t) => t.totalSpan.inMicroseconds > 1000000 / hz)
          .length,
    );
  }
}
