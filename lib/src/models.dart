import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'config.dart';

enum RebuildScanStatus { off, active, debugAutoUnsupported, noTargets }

@immutable
class RebuildEvent {
  const RebuildEvent({
    required this.id,
    required this.widgetType,
    required this.frame,
    required this.micros,
    this.name,
    this.tag,
    this.rect,
  });

  final int id;
  final String? name;
  final Object? tag;
  final Type widgetType;
  final int frame;
  final int micros;
  final Rect? rect;
}

class RebuildEntry {
  RebuildEntry({
    required this.id,
    required this.widgetType,
    this.name,
    this.tag,
  });

  final int id;
  final Type widgetType;
  String? name;
  Object? tag;
  int totalCount = 0;
  int frameCount = 0;
  int lastFrame = 0;
  int lastMicros = 0;
  Rect? rect;

  final ListQueue<int> _recentMicros = ListQueue<int>();

  void addHit({
    required int micros,
    required int frame,
    required Duration window,
  }) {
    totalCount += 1;
    frameCount = frame == lastFrame ? frameCount + 1 : 1;
    lastFrame = frame;
    lastMicros = micros;
    _recentMicros.addLast(micros);
    trim(window: window, nowMicros: micros);
  }

  int recentCount(Duration window, int nowMicros) {
    trim(window: window, nowMicros: nowMicros);
    return _recentMicros.length;
  }

  void trim({required Duration window, required int nowMicros}) {
    final cutoff = nowMicros - window.inMicroseconds;
    while (_recentMicros.isNotEmpty && _recentMicros.first < cutoff) {
      _recentMicros.removeFirst();
    }
  }
}

@immutable
class RebuildScanEntrySnapshot {
  const RebuildScanEntrySnapshot({
    required this.id,
    required this.widgetType,
    required this.totalCount,
    required this.recentCount,
    required this.frameCount,
    required this.lastFrame,
    required this.lastMicros,
    this.name,
    this.tag,
    this.rect,
  });

  final int id;
  final String? name;
  final Object? tag;
  final Type widgetType;
  final int totalCount;
  final int recentCount;
  final int frameCount;
  final int lastFrame;
  final int lastMicros;
  final Rect? rect;
}

@immutable
class RebuildScanSnapshot {
  RebuildScanSnapshot({
    required this.frameNumber,
    required this.totalRebuilds,
    required this.enabled,
    required this.mode,
    required this.status,
    required this.config,
    required Set<int> rebuiltThisFrame,
    required List<RebuildScanEntrySnapshot> topEntries,
    required Map<int, RebuildScanEntrySnapshot> entriesById,
  }) : rebuiltThisFrame = Set.unmodifiable(rebuiltThisFrame),
       topEntries = List.unmodifiable(topEntries),
       entriesById = Map.unmodifiable(entriesById);

  final int frameNumber;
  final int totalRebuilds;
  final bool enabled;
  final RebuildScanMode mode;
  final RebuildScanStatus status;
  final RebuildScanConfig config;
  final Set<int> rebuiltThisFrame;
  final List<RebuildScanEntrySnapshot> topEntries;
  final Map<int, RebuildScanEntrySnapshot> entriesById;

  factory RebuildScanSnapshot.initial({
    required RebuildScanConfig config,
    required bool enabled,
    RebuildScanMode mode = RebuildScanMode.off,
    RebuildScanStatus status = RebuildScanStatus.off,
  }) {
    return RebuildScanSnapshot(
      frameNumber: 0,
      totalRebuilds: 0,
      enabled: enabled,
      mode: mode,
      status: status,
      config: config,
      rebuiltThisFrame: const <int>{},
      topEntries: const <RebuildScanEntrySnapshot>[],
      entriesById: const <int, RebuildScanEntrySnapshot>{},
    );
  }
}
