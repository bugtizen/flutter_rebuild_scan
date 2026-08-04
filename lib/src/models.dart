import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'config.dart';

/// Current operational state of the rebuild scanner.
enum RebuildScanStatus {
  /// Tracking is disabled.
  off,

  /// Tracking is active and counters can be recorded.
  active,

  /// Debug auto mode was requested outside a debug build.
  debugAutoUnsupported,

  /// Targeted mode is active but no marked widgets have rebuilt yet.
  noTargets,
}

/// Internal rebuild event captured before it is aggregated.
@immutable
class RebuildEvent {
  /// Creates a rebuild event.
  const RebuildEvent({
    required this.id,
    required this.widgetType,
    required this.frame,
    required this.micros,
    this.name,
    this.tag,
    this.rect,
  });

  /// Stable id for the tracked widget or element.
  final int id;

  /// Human-readable name shown in the panel.
  final String? name;

  /// Optional caller-provided grouping tag.
  final Object? tag;

  /// Runtime widget type associated with the rebuild.
  final Type widgetType;

  /// Frame number when the rebuild was recorded.
  final int frame;

  /// Timestamp in microseconds when the rebuild was recorded.
  final int micros;

  /// Last measured global rectangle, when available.
  final Rect? rect;
}

/// Mutable aggregate state for one tracked widget entry.
class RebuildEntry {
  /// Creates an aggregate rebuild entry.
  RebuildEntry({
    required this.id,
    required this.widgetType,
    this.name,
    this.tag,
  });

  /// Stable id for this tracked entry.
  final int id;

  /// Runtime widget type for this tracked entry.
  final Type widgetType;

  /// Human-readable name shown in the panel.
  String? name;

  /// Optional caller-provided grouping tag.
  Object? tag;

  /// Total rebuilds recorded for this entry.
  int totalCount = 0;

  /// Rebuilds recorded in the latest frame for this entry.
  int frameCount = 0;

  /// Last frame number where this entry rebuilt.
  int lastFrame = 0;

  /// Last rebuild timestamp in microseconds.
  int lastMicros = 0;

  /// Last measured global rectangle, when available.
  Rect? rect;

  final ListQueue<int> _recentMicros = ListQueue<int>();

  /// Adds one rebuild hit to this entry.
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

  /// Returns rebuild count inside [window] ending at [nowMicros].
  int recentCount(Duration window, int nowMicros) {
    trim(window: window, nowMicros: nowMicros);
    return _recentMicros.length;
  }

  /// Removes rebuild timestamps older than [window].
  void trim({required Duration window, required int nowMicros}) {
    final cutoff = nowMicros - window.inMicroseconds;
    while (_recentMicros.isNotEmpty && _recentMicros.first < cutoff) {
      _recentMicros.removeFirst();
    }
  }
}

/// Immutable panel/overlay snapshot for one tracked widget entry.
@immutable
class RebuildScanEntrySnapshot {
  /// Creates an immutable tracked entry snapshot.
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

  /// Stable id for this tracked entry.
  final int id;

  /// Human-readable name shown in the panel.
  final String? name;

  /// Optional caller-provided grouping tag.
  final Object? tag;

  /// Runtime widget type for this tracked entry.
  final Type widgetType;

  /// Total rebuilds recorded for this entry.
  final int totalCount;

  /// Rebuilds recorded inside the active sample window.
  final int recentCount;

  /// Rebuilds recorded in the latest frame.
  final int frameCount;

  /// Last frame number where this entry rebuilt.
  final int lastFrame;

  /// Last rebuild timestamp in microseconds.
  final int lastMicros;

  /// Last measured global rectangle, when available.
  final Rect? rect;
}

/// Immutable scanner state emitted to overlays and controller listeners.
@immutable
class RebuildScanSnapshot {
  /// Creates a scanner snapshot.
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

  /// Latest frame number observed by the scanner.
  final int frameNumber;

  /// Total rebuilds recorded across all entries.
  final int totalRebuilds;

  /// Whether the scanner is currently recording rebuilds.
  final bool enabled;

  /// Configured scan mode.
  final RebuildScanMode mode;

  /// Effective scanner status.
  final RebuildScanStatus status;

  /// Active scanner configuration.
  final RebuildScanConfig config;

  /// Entry ids that rebuilt in the latest emitted frame.
  final Set<int> rebuiltThisFrame;

  /// Ranked entries shown in the panel.
  final List<RebuildScanEntrySnapshot> topEntries;

  /// All retained entries keyed by tracked id.
  final Map<int, RebuildScanEntrySnapshot> entriesById;

  /// Creates the initial empty scanner snapshot.
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
