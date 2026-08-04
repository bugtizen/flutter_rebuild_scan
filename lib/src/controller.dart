import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'frame_tracker.dart';
import 'models.dart';
import 'registry.dart';
import 'utils/rect_utils.dart';
import 'utils/throttler.dart';

/// Imperative controller for reading and updating rebuild scan state.
class RebuildScanController {
  /// Creates a rebuild scan controller.
  RebuildScanController({
    RebuildScanConfig? config,
    RebuildScanMode mode = RebuildScanMode.off,
    RebuildScanStatus status = RebuildScanStatus.off,
  }) : _config = config ?? const RebuildScanConfig(),
       _mode = mode,
       _status = status,
       _snapshotNotifier = ValueNotifier<RebuildScanSnapshot>(
         RebuildScanSnapshot.initial(
           config: config ?? const RebuildScanConfig(),
           enabled: status == RebuildScanStatus.active,
           mode: mode,
           status: status,
         ),
       ) {
    _frameTracker = FrameTracker(onFrameEnd: _onFrameEnd);
  }

  late final FrameTracker _frameTracker;
  final ScanRegistry _registry = ScanRegistry();
  final Throttler _topListThrottler = Throttler(
    const Duration(milliseconds: 120),
  );
  final ValueNotifier<RebuildScanSnapshot> _snapshotNotifier;

  RebuildScanConfig _config;
  RebuildScanMode _mode;
  RebuildScanStatus _status;
  bool _attached = false;
  final Map<int, Element> _pendingRectElements = <int, Element>{};
  List<RebuildScanEntrySnapshot> _cachedTopEntries =
      const <RebuildScanEntrySnapshot>[];

  /// Listenable that emits a [RebuildScanSnapshot] when scanner state changes.
  ValueListenable<RebuildScanSnapshot> get listenable => _snapshotNotifier;

  /// Current scanner snapshot.
  RebuildScanSnapshot get snapshot => _snapshotNotifier.value;

  /// Active scanner configuration.
  RebuildScanConfig get config => _config;

  /// Whether the scanner currently accepts rebuild events.
  bool get isEnabled =>
      _status == RebuildScanStatus.active ||
      _status == RebuildScanStatus.noTargets;

  /// Configured scan mode.
  RebuildScanMode get mode => _mode;

  /// Effective scanner status.
  RebuildScanStatus get status => _status;

  /// Attaches the controller to the frame scheduler.
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    if (isEnabled) {
      _frameTracker.start();
    }
    _emitSnapshot(forceTopRefresh: true);
  }

  /// Detaches the controller from frame scheduling.
  void detach() {
    if (!_attached) {
      return;
    }
    _attached = false;
    _frameTracker.stop();
  }

  /// Updates the configured scan mode and effective status.
  void setMode({
    required RebuildScanMode mode,
    required RebuildScanStatus status,
  }) {
    if (_mode == mode && _status == status) {
      return;
    }

    _mode = mode;
    _status = status;
    if (_attached) {
      if (isEnabled) {
        _frameTracker.start();
      } else {
        _frameTracker.stop();
      }
    }
    _emitSnapshot(forceTopRefresh: true, rebuiltThisFrame: const <int>{});
  }

  /// Replaces the active scanner configuration.
  void setConfig(RebuildScanConfig config) {
    if (_config == config) {
      return;
    }
    _config = config;
    _topListThrottler.reset();
    _emitSnapshot(forceTopRefresh: true);
  }

  /// Clears all collected rebuild statistics.
  void clearStats() {
    _registry.clear();
    _pendingRectElements.clear();
    _cachedTopEntries = const <RebuildScanEntrySnapshot>[];
    _emitSnapshot(forceTopRefresh: true, rebuiltThisFrame: const <int>{});
  }

  /// Records one rebuild for a tracked widget id.
  void recordRebuild({
    required int id,
    required Type widgetType,
    String? name,
    Object? tag,
  }) {
    if (!isEnabled || _config.ignoreTypes.contains(widgetType)) {
      return;
    }

    final nowMicros = _nowMicros();
    if (_status == RebuildScanStatus.noTargets) {
      _status = RebuildScanStatus.active;
    }
    _registry.onRebuild(
      RebuildEvent(
        id: id,
        name: name,
        tag: tag,
        widgetType: widgetType,
        frame: _frameTracker.currentFrame,
        micros: nowMicros,
      ),
      _config.sampleWindow,
    );

    if (!_attached) {
      _emitSnapshot(forceTopRefresh: true, nowMicros: nowMicros);
    }
  }

  /// Updates the last measured rectangle for a tracked widget id.
  void updateRect({required int id, required Rect? rect}) {
    if (!isEnabled || !_config.trackRects) {
      return;
    }
    _registry.updateRect(id, rect: rect);
  }

  /// Queues a widget element for safe rectangle measurement at frame end.
  void queueRectMeasurement({required int id, required Element element}) {
    if (!isEnabled || !_config.trackRects) {
      return;
    }
    _pendingRectElements[id] = element;
  }

  @visibleForTesting
  /// Number of queued rectangle measurements waiting for frame end.
  int get pendingRectMeasurementCount => _pendingRectElements.length;

  /// Marks an entry as disposed and removes pending rectangle work.
  void markDisposed(int id) {
    _pendingRectElements.remove(id);
    _registry.markDisposed(id);
  }

  /// Releases scheduler and notifier resources.
  void dispose() {
    detach();
    _snapshotNotifier.dispose();
  }

  void _onFrameEnd(int frameNumber) {
    if (!isEnabled) {
      return;
    }

    final nowMicros = _nowMicros();
    final rebuiltIds = _registry.takeRebuiltThisFrame();

    _flushRectMeasurements();

    _registry.prune(
      maxEntries: _config.maxEntries,
      staleDuration: _computeStaleWindow(_config.sampleWindow),
      nowMicros: nowMicros,
    );

    _emitSnapshot(
      frameNumber: frameNumber,
      rebuiltThisFrame: rebuiltIds,
      nowMicros: nowMicros,
    );
  }

  void _flushRectMeasurements() {
    if (!_config.trackRects || _pendingRectElements.isEmpty) {
      _pendingRectElements.clear();
      return;
    }

    final pending = Map<int, Element>.of(_pendingRectElements);
    _pendingRectElements.clear();
    pending.forEach((id, element) {
      _registry.updateRect(id, rect: RectUtils.getGlobalRect(element));
    });
  }

  void _emitSnapshot({
    int? frameNumber,
    Set<int>? rebuiltThisFrame,
    int? nowMicros,
    bool forceTopRefresh = false,
  }) {
    final micros = nowMicros ?? _nowMicros();

    if (forceTopRefresh || _topListThrottler.shouldRun(nowMicros: micros)) {
      _cachedTopEntries = _registry
          .snapshotTopRebuilders(
            window: _config.sampleWindow,
            nowMicros: micros,
            limit: 30,
          )
          .where((entry) => entry.recentCount >= _config.minRebuildsToShow)
          .toList(growable: false);
    }

    final entriesById = _registry.snapshotEntries(
      window: _config.sampleWindow,
      nowMicros: micros,
    );

    _snapshotNotifier.value = RebuildScanSnapshot(
      frameNumber: frameNumber ?? _frameTracker.currentFrame,
      totalRebuilds: _registry.totalRebuilds,
      enabled: isEnabled,
      mode: _mode,
      status: _status,
      config: _config,
      rebuiltThisFrame: rebuiltThisFrame ?? const <int>{},
      topEntries: _cachedTopEntries,
      entriesById: entriesById,
    );
  }

  Duration _computeStaleWindow(Duration sampleWindow) {
    final micros = sampleWindow.inMicroseconds * 10;
    final minimum = const Duration(seconds: 3).inMicroseconds;
    return Duration(microseconds: micros < minimum ? minimum : micros);
  }

  static int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
