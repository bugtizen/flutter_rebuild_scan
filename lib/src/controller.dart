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
import 'utils/visual_refresh.dart';

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
    return _snapshotNotifier.value;
  }

  /// Paint state for capped visible targets.
  RebuildScanSnapshot visualSnapshot() {
    prepareVisualEntries();
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

  final VisualRefresh _refresh = VisualRefresh();
  Timer? _wake;
  int _lastVisual = 0;
  int _paintFrame = -1;
  int _cursor = 0;
  final Set<int> _geometryPending = {};
  final List<RebuildScanEntrySnapshot> _drawEntries = [];

  /// Prepares the capped drawing list without an aggregate snapshot.
  List<RebuildScanEntrySnapshot> prepareVisualEntries() {
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
    _geometryPending.removeWhere((id) => !_elements.containsKey(id));
    final geometry = RectMeasurementPass();
    final watch = Stopwatch()..start();
    final targets = _elements.entries.toList(growable: false);
    var measured = 0;
    while (measured < targets.length) {
      final item = targets[(_cursor + measured) % targets.length];
      _registry.updateRect(
        item.key,
        rect: geometry.measure(item.value.target!),
      );
      _geometryPending.remove(item.key);
      measured++;
      if (watch.elapsedMicroseconds >= 1000) break;
    }
    if (targets.isNotEmpty) _cursor = (_cursor + measured) % targets.length;
    _lastVisual = _nowMicros();
    _wake?.cancel();
    _wake = null;
    _expiry?.cancel();
    _expiry = null;
    _registry.fillVisibleEntries(
      _drawEntries,
      _elements.keys,
      _config.sampleWindow,
      _lastVisual,
    );
    if (_drawEntries.isNotEmpty) {
      final lifetime = _config.highlightMode == HighlightMode.flash
          ? 400001
          : _config.sampleWindow.inMicroseconds + 1;
      final oldest = _drawEntries
          .map((e) => e.lastMicros)
          .reduce((a, b) => a < b ? a : b);
      final delay = lifetime - (_lastVisual - oldest);
      _expiry = Timer(Duration(microseconds: delay < 1 ? 1 : delay), () {
        _expiry = null;
        if (isEnabled) _paintSignal.emit();
      });
      if (_geometryPending.isNotEmpty) {
        _wake = Timer(Duration(microseconds: _refresh.intervalMicros), () {
          _wake = null;
          if (isEnabled) _paintSignal.emit();
        });
      }
    }
    return _drawEntries;
  }

  /// Reports preparation and paint cost for adaptive visual updates.
  void recordVisualCost(int micros) => _refresh.record(micros, _nowMicros());

  void _requestVisual() {
    if (_elements.isEmpty || _paintFrame == _frameTracker.currentFrame) return;
    final remaining = _refresh.intervalMicros - (_nowMicros() - _lastVisual);
    if (remaining > 0) {
      _wake ??= Timer(Duration(microseconds: remaining), () {
        _wake = null;
        if (isEnabled) _paintSignal.emit();
      });
      return;
    }
    _paintFrame = _frameTracker.currentFrame;
    _paintSignal.emit();
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
    _wake?.cancel();
    _wake = null;
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
      _wake?.cancel();
      _wake = null;
      _pendingRectElements.clear();
      _geometryPending.clear();
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
    _expiry?.cancel();
    _wake?.cancel();
    _wake = null;
    _paintFrame = -1;
    _lastVisual = 0;
    if (!config.trackRects) _elements.clear();
    _paintSignal.emit();
    _topListThrottler.reset();
    _emitSnapshot(forceTopRefresh: true);
  }

  /// Clears all collected rebuild statistics.
  void clearStats() {
    _expiry?.cancel();
    _wake?.cancel();
    _wake = null;
    _drawEntries.clear();
    _registry.clear();
    _metrics.clear();
    _frameMetrics.value = const FrameMetricsSnapshot();
    _geometryPending.clear();
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

    if (!_attached && _snapshotNotifier.observed) {
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
    if (_pendingRectElements[id] == element) return;
    if (_pendingRectElements.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendingRectElements.clear();
      });
    }
    _pendingRectElements[id] = element;
    while (_pendingRectElements.length > _config.maxHighlights) {
      _pendingRectElements.remove(_pendingRectElements.keys.first);
    }
    _geometryPending.add(id);
    final previous = _elements.remove(id);
    _elements[id] = previous?.target == element
        ? previous!
        : WeakReference(element);
    while (_elements.length > _config.maxHighlights) {
      final evicted = _elements.keys.first;
      _elements.remove(evicted);
      _geometryPending.remove(evicted);
    }
    _requestVisual();
  }

  @visibleForTesting
  /// Number of queued rectangle measurements waiting for frame end.
  int get pendingRectMeasurementCount => _pendingRectElements.length;

  /// Marks an entry as disposed and removes pending rectangle work.
  void markDisposed(int id) {
    _elements.remove(id);
    _geometryPending.remove(id);
    _pendingRectElements.remove(id);
    _registry.markDisposed(id);
  }

  /// Releases scheduler and notifier resources.
  void dispose() {
    _expiry?.cancel();
    detach();
    _pendingRectElements.clear();
    _drawEntries.clear();
    _geometryPending.clear();
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
    _requestVisual();
    _pendingRectElements.clear();
    _registry.clearRebuiltThisFrame();
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
