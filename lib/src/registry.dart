// ignore_for_file: public_member_api_docs

import 'dart:collection';
import 'dart:ui';

import 'models.dart';

class ScanRegistry {
  final Map<int, RebuildEntry> _entries = <int, RebuildEntry>{};
  final Set<int> _rebuiltThisFrame = <int>{};
  int _totalRebuilds = 0;
  int currentFrame = 0;

  int get totalRebuilds => _totalRebuilds;
  int get entryCount => _entries.length;
  bool isRecent(int id, int now, int age) =>
      _entries.containsKey(id) && now - _entries[id]!.lastMicros <= age;

  void onRebuild(RebuildEvent event, Duration window) {
    record(
      id: event.id,
      widgetType: event.widgetType,
      name: event.name,
      tag: event.tag,
      rect: event.rect,
      frame: event.frame,
      micros: event.micros,
      window: window,
    );
  }

  void record({
    required int id,
    required Type widgetType,
    String? name,
    Object? tag,
    Rect? rect,
    required int frame,
    required int micros,
    required Duration window,
    int maxEntries = 2000,
  }) {
    currentFrame = frame;
    final entry =
        _entries.remove(id) ??
        RebuildEntry(id: id, widgetType: widgetType, name: name, tag: tag);
    entry.name = name ?? entry.name;
    entry.tag = tag ?? entry.tag;
    entry.rect = rect ?? entry.rect;
    entry.addHit(micros: micros, frame: frame, window: window);
    _entries[id] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _rebuiltThisFrame.add(id);
    _totalRebuilds++;
  }

  void updateRect(int id, {required Rect? rect}) {
    final entry = _entries[id];
    if (entry == null) {
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

    int compare(RebuildScanEntrySnapshot a, RebuildScanEntrySnapshot b) {
      final recent = b.recentCount.compareTo(a.recentCount);
      if (recent != 0) return recent;
      final total = b.totalCount.compareTo(a.totalCount);
      return total != 0 ? total : b.lastMicros.compareTo(a.lastMicros);
    }

    final snapshots = <RebuildScanEntrySnapshot>[];
    for (final entry in _entries.values) {
      final candidate = _toSnapshot(
        entry,
        window: window,
        nowMicros: nowMicros,
      );
      if (snapshots.length == limit &&
          compare(candidate, snapshots.last) >= 0) {
        continue;
      }
      var index = 0;
      while (index < snapshots.length &&
          compare(candidate, snapshots[index]) >= 0) {
        index++;
      }
      snapshots.insert(index, candidate);
      if (snapshots.length > limit) snapshots.removeLast();
    }

    return snapshots;
  }

  Map<int, RebuildScanEntrySnapshot> snapshotEntries({
    Iterable<int>? ids,
    required Duration window,
    required int nowMicros,
  }) {
    final map = HashMap<int, RebuildScanEntrySnapshot>();
    for (final id in ids ?? _entries.keys) {
      final entry = _entries[id];
      if (entry == null) continue;
      map[id] = _toSnapshot(entry, window: window, nowMicros: nowMicros);
    }
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
      frameCount: entry.lastFrame == currentFrame ? entry.frameCount : 0,
      lastFrame: entry.lastFrame,
      lastMicros: entry.lastMicros,
      rect: entry.rect,
    );
  }
}
