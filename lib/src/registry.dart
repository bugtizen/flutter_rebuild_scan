// ignore_for_file: public_member_api_docs

import 'dart:collection';
import 'dart:ui';

import 'models.dart';

class ScanRegistry {
  final Map<int, RebuildEntry> _entries = <int, RebuildEntry>{};
  final Set<int> _rebuiltThisFrame = <int>{};
  int _totalRebuilds = 0;

  int get totalRebuilds => _totalRebuilds;
  int get entryCount => _entries.length;

  void onRebuild(RebuildEvent event, Duration window) {
    final entry = _entries.putIfAbsent(
      event.id,
      () => RebuildEntry(
        id: event.id,
        name: event.name,
        tag: event.tag,
        widgetType: event.widgetType,
      ),
    );

    entry
      ..name = event.name ?? entry.name
      ..tag = event.tag ?? entry.tag
      ..rect = event.rect ?? entry.rect;

    entry.addHit(micros: event.micros, frame: event.frame, window: window);

    _rebuiltThisFrame.add(event.id);
    _totalRebuilds += 1;
  }

  void updateRect(int id, {required Rect? rect}) {
    final entry = _entries[id];
    if (entry == null || rect == null) {
      return;
    }
    entry.rect = rect;
  }

  void markDisposed(int id) {
    _entries.remove(id);
    _rebuiltThisFrame.remove(id);
  }

  Set<int> takeRebuiltThisFrame() {
    final result = Set<int>.from(_rebuiltThisFrame);
    _rebuiltThisFrame.clear();
    return result;
  }

  void clear() {
    _entries.clear();
    _rebuiltThisFrame.clear();
    _totalRebuilds = 0;
  }

  void prune({
    required int maxEntries,
    required Duration staleDuration,
    required int nowMicros,
  }) {
    if (_entries.isEmpty) {
      return;
    }

    final staleCutoff = nowMicros - staleDuration.inMicroseconds;
    final staleIds = <int>[];
    _entries.forEach((id, entry) {
      if (entry.lastMicros < staleCutoff) {
        staleIds.add(id);
      }
    });

    for (final id in staleIds) {
      _entries.remove(id);
      _rebuiltThisFrame.remove(id);
    }

    if (_entries.length <= maxEntries) {
      return;
    }

    final ordered = _entries.values.toList()
      ..sort((a, b) => a.lastMicros.compareTo(b.lastMicros));

    final removeCount = _entries.length - maxEntries;
    for (var i = 0; i < removeCount; i += 1) {
      final id = ordered[i].id;
      _entries.remove(id);
      _rebuiltThisFrame.remove(id);
    }
  }

  List<RebuildScanEntrySnapshot> snapshotTopRebuilders({
    required Duration window,
    required int nowMicros,
    int limit = 25,
  }) {
    if (_entries.isEmpty) {
      return const <RebuildScanEntrySnapshot>[];
    }

    final snapshots = _entries.values
        .map(
          (entry) => _toSnapshot(entry, window: window, nowMicros: nowMicros),
        )
        .toList();

    snapshots.sort((a, b) {
      final recent = b.recentCount.compareTo(a.recentCount);
      if (recent != 0) {
        return recent;
      }
      final total = b.totalCount.compareTo(a.totalCount);
      if (total != 0) {
        return total;
      }
      return b.lastMicros.compareTo(a.lastMicros);
    });

    if (snapshots.length > limit) {
      return snapshots.sublist(0, limit);
    }

    return snapshots;
  }

  Map<int, RebuildScanEntrySnapshot> snapshotEntries({
    required Duration window,
    required int nowMicros,
  }) {
    final map = HashMap<int, RebuildScanEntrySnapshot>();
    _entries.forEach((id, entry) {
      map[id] = _toSnapshot(entry, window: window, nowMicros: nowMicros);
    });
    return map;
  }

  RebuildScanEntrySnapshot _toSnapshot(
    RebuildEntry entry, {
    required Duration window,
    required int nowMicros,
  }) {
    return RebuildScanEntrySnapshot(
      id: entry.id,
      name: entry.name,
      tag: entry.tag,
      widgetType: entry.widgetType,
      totalCount: entry.totalCount,
      recentCount: entry.recentCount(window, nowMicros),
      frameCount: entry.frameCount,
      lastFrame: entry.lastFrame,
      lastMicros: entry.lastMicros,
      rect: entry.rect,
    );
  }
}
