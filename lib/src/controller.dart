import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'frame_metrics.dart';

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
       _snapshotNotifier = _SnapshotNotifier(
         RebuildScanSnapshot.initial(
           config: config ?? const RebuildScanConfig(),
           enabled: status == RebuildScanStatus.active,
           mode: mode,
           status: status,
         ),
       ) {
    _validateConfig(_config);
    _frameTracker = FrameTracker(onFrameEnd: _onFrameEnd);
  }

  /// Paint-only notifications.
  /// Configuration changes independent of aggregate snapshots.
  final ValueNotifier<int> settingsRevision = ValueNotifier(0);
  final _PaintSignal _paintSignal = _PaintSignal();

  /// Signal consumed by the highlight painter.
  Listenable get repaint => _paintSignal;
  final FrameMetricsCollector _metrics = FrameMetricsCollector();
  final ValueNotifier<FrameMetricsSnapshot> _frameMetrics = ValueNotifier(
    const FrameMetricsSnapshot(),
  );

  /// Completed engine timing summaries.
  ValueListenable<FrameMetricsSnapshot> get frameMetrics => _frameMetrics;
  bool _timingsAttached = false;
  int _lastPublication = 0;
  Timer? _expiry;
  final Map<int, WeakReference<Element>> _elements = {};
  static final Stopwatch _clock = Stopwatch()..start();
  static final int _epoch = DateTime.now().microsecondsSinceEpoch;
  void _onTimings(List<FrameTiming> timings) {
    if (_attached && isEnabled) _metrics.add(timings);
  }

  void _syncTimings() {
    final wanted = _attached && isEnabled && _config.collectFrameTimings;
    if (wanted == _timingsAttached) return;
    _timingsAttached = wanted;
    if (wanted) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
  }

  /// Capture a fresh aggregate snapshot.
  RebuildScanSnapshot captureSnapshot() {
    _emitSnapshot(forceTopRefresh: true);
    return snapshot;
  }

  /// Paint state for capped visible targets.
  RebuildScanSnapshot visualSnapshot() {
    _elements.removeWhere(
      (id, ref) =>
          ref.target == null ||
          !ref.target!.mounted ||
          !_registry.isRecent(
            id,
            _nowMicros(),
            _config.highlightMode == HighlightMode.flash
                ? 400000
                : _config.sampleWindow.inMicroseconds,
          ),
    );
    for (final item in _elements.entries) {
      _registry.updateRect(
        item.key,
        rect: RectUtils.getGlobalRect(item.value.target!),
      );
    }
    return RebuildScanSnapshot(
      frameNumber: _frameTracker.currentFrame,
      totalRebuilds: _registry.totalRebuilds,
      enabled: isEnabled,
      mode: _mode,
      status: _status,
      config: _config,
      rebuiltThisFrame: const {},
      topEntries: const [],
      entriesById: _registry.snapshotEntries(
        window: _config.sampleWindow,
        nowMicros: _nowMicros(),
        ids: _elements.keys,
      ),
    );
  }

  late final FrameTracker _frameTracker;
  final ScanRegistry _registry = ScanRegistry();
  final Throttler _topListThrottler = Throttler(
    const Duration(milliseconds: 120),
  );
  final _SnapshotNotifier _snapshotNotifier;

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
  RebuildScanSnapshot get snapshot => RebuildScanSnapshot(
    frameNumber: _frameTracker.currentFrame,
    totalRebuilds: _registry.totalRebuilds,
    enabled: isEnabled,
    mode: _mode,
    status: _status,
    config: _config,
    rebuiltThisFrame: const {},
    topEntries: _registry
        .snapshotTopRebuilders(
          window: _config.sampleWindow,
          nowMicros: _nowMicros(),
          limit: 30,
        )
        .where((e) => e.recentCount >= _config.minRebuildsToShow)
        .toList(),
    entriesById: _registry.snapshotEntries(
      window: _config.sampleWindow,
      nowMicros: _nowMicros(),
    ),
  );

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
    _syncTimings();
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
    _syncTimings();
    _expiry?.cancel();
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
    if (!isEnabled) {
      _expiry?.cancel();
      _pendingRectElements.clear();
      _elements.clear();
    }
    settingsRevision.value++;
    _syncTimings();
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
    _validateConfig(config);
    if (_config == config) {
      return;
    }
    _config = config;
    settingsRevision.value++;
    _syncTimings();
    if (!config.trackRects) _elements.clear();
    _topListThrottler.reset();
    _emitSnapshot(forceTopRefresh: true);
  }

  /// Clears all collected rebuild statistics.
  void clearStats() {
    _registry.clear();
    _metrics.clear();
    _frameMetrics.value = const FrameMetricsSnapshot();
    _elements.clear();
    _paintSignal.emit();
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
    _registry.record(
      id: id,
      name: name,
      tag: tag,
      widgetType: widgetType,
      frame: _frameTracker.currentFrame,
      micros: nowMicros,
      window: _config.sampleWindow,
      maxEntries: _config.maxEntries,
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
    if (_pendingRectElements.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendingRectElements.clear();
      });
    }
    _pendingRectElements[id] = element;
    while (_pendingRectElements.length > _config.maxHighlights) {
      _pendingRectElements.remove(_pendingRectElements.keys.first);
    }
    _elements.remove(id);
    _elements[id] = WeakReference(element);
    while (_elements.length > _config.maxHighlights) {
      _elements.remove(_elements.keys.first);
    }
    _paintSignal.emit();
    _expiry?.cancel();
    _expiry = Timer(
      _config.highlightMode == HighlightMode.flash
          ? const Duration(milliseconds: 401)
          : _config.sampleWindow + const Duration(milliseconds: 1),
      () {
        _paintSignal.emit();
      },
    );
  }

  @visibleForTesting
  /// Number of queued rectangle measurements waiting for frame end.
  int get pendingRectMeasurementCount => _pendingRectElements.length;

  /// Marks an entry as disposed and removes pending rectangle work.
  void markDisposed(int id) {
    _elements.remove(id);
    _pendingRectElements.remove(id);
    _registry.markDisposed(id);
  }

  /// Releases scheduler and notifier resources.
  void dispose() {
    _expiry?.cancel();
    detach();
    _elements.clear();
    settingsRevision.dispose();
    _frameMetrics.dispose();
    _paintSignal.dispose();
    _snapshotNotifier.dispose();
  }

  void _onFrameEnd(int frameNumber) {
    if (!isEnabled) {
      return;
    }

    _registry.currentFrame = frameNumber;
    if (_elements.isNotEmpty) _paintSignal.emit();
    _pendingRectElements.clear();
    _registry.takeRebuiltThisFrame();
    final now = _nowMicros();
    if (now - _lastPublication < _config.statsInterval.inMicroseconds) return;
    _lastPublication = now;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final hz =
        _config.targetRefreshRate ??
        (views.isEmpty ? 60.0 : views.first.display.refreshRate);
    if (_config.collectFrameTimings) {
      _frameMetrics.value = _metrics.snapshot(hz > 0 ? hz : 60);
    }
    _registry.prune(
      maxEntries: _config.maxEntries,
      staleDuration: _computeStaleWindow(_config.sampleWindow),
      nowMicros: now,
    );
    if (_snapshotNotifier.observed) {
      _emitSnapshot(frameNumber: frameNumber, nowMicros: now);
    }
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

  static void _validateConfig(RebuildScanConfig config) {
    if (config.sampleWindow.inMicroseconds <= 0 ||
        config.statsInterval.inMicroseconds <= 0 ||
        config.maxEntries <= 0 ||
        config.maxHighlights <= 0 ||
        config.minRebuildsToShow <= 0 ||
        !config.heatmapMaxRebuildsPerSecond.isFinite ||
        config.heatmapMaxRebuildsPerSecond <= 0 ||
        (config.targetRefreshRate != null &&
            (!config.targetRefreshRate!.isFinite ||
                config.targetRefreshRate! <= 0))) {
      throw ArgumentError(
        'Scanner windows, capacities, thresholds and refresh rates must be positive and finite.',
      );
    }
  }

  Duration _computeStaleWindow(Duration sampleWindow) {
    final micros = sampleWindow.inMicroseconds * 10;
    final minimum = const Duration(seconds: 3).inMicroseconds;
    return Duration(microseconds: micros < minimum ? minimum : micros);
  }

  /// Anchored monotonic timestamp shared by counters and painting.
  int get timestampMicros => _nowMicros();

  static int _nowMicros() => _epoch + _clock.elapsedMicroseconds;
}

class _PaintSignal extends ChangeNotifier {
  void emit() => notifyListeners();
}

class _SnapshotNotifier extends ValueNotifier<RebuildScanSnapshot> {
  _SnapshotNotifier(super.value);
  bool get observed => hasListeners;
}
