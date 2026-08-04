import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rebuild_scan/src/models.dart';
import 'package:flutter_rebuild_scan/src/registry.dart';

void main() {
  group('ScanRegistry', () {
    test('increments counts and keeps ordering by recent count', () {
      final registry = ScanRegistry();

      registry.onRebuild(
        const RebuildEvent(
          id: 1,
          name: 'A',
          widgetType: Text,
          frame: 1,
          micros: 100,
        ),
        const Duration(seconds: 1),
      );

      registry.onRebuild(
        const RebuildEvent(
          id: 1,
          name: 'A',
          widgetType: Text,
          frame: 2,
          micros: 200,
        ),
        const Duration(seconds: 1),
      );

      registry.onRebuild(
        const RebuildEvent(
          id: 2,
          name: 'B',
          widgetType: Column,
          frame: 2,
          micros: 220,
        ),
        const Duration(seconds: 1),
      );

      final top = registry.snapshotTopRebuilders(
        window: const Duration(seconds: 1),
        nowMicros: 250,
      );

      expect(registry.totalRebuilds, 3);
      expect(top.first.id, 1);
      expect(top.first.totalCount, 2);
      expect(top.first.recentCount, 2);
      expect(top.first.frameCount, 1);
      expect(top[1].id, 2);
    });

    test('sample window removes stale recent count', () {
      final registry = ScanRegistry();

      registry.onRebuild(
        const RebuildEvent(id: 10, widgetType: Row, frame: 1, micros: 100000),
        const Duration(milliseconds: 200),
      );

      registry.onRebuild(
        const RebuildEvent(id: 10, widgetType: Row, frame: 2, micros: 250000),
        const Duration(milliseconds: 200),
      );

      final top = registry.snapshotTopRebuilders(
        window: const Duration(milliseconds: 200),
        nowMicros: 360000,
      );

      expect(top.single.totalCount, 2);
      expect(top.single.recentCount, 1);
    });

    test('prune removes stale and caps max entries', () {
      final registry = ScanRegistry();

      for (var i = 0; i < 6; i += 1) {
        registry.onRebuild(
          RebuildEvent(id: i, widgetType: Container, frame: i, micros: i * 100),
          const Duration(seconds: 1),
        );
      }

      registry.prune(
        maxEntries: 3,
        staleDuration: const Duration(milliseconds: 500),
        nowMicros: 900,
      );

      final entries = registry.snapshotEntries(
        window: const Duration(seconds: 1),
        nowMicros: 900,
      );

      expect(entries.length, 3);
      expect(entries.keys, containsAll(<int>{3, 4, 5}));
    });
  });
}
