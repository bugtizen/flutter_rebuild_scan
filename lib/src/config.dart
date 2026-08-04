import 'package:flutter/foundation.dart';

/// Visual style used when drawing rebuild highlights.
enum HighlightMode {
  /// Briefly flashes widgets that rebuilt recently.
  flash,

  /// Colors widgets by rebuild frequency within the sample window.
  heatmap,

  /// Draws an outline around tracked widget rectangles.
  outline,
}

/// Ways the rebuild scan panel can be opened.
enum PanelOpenMethod {
  /// Shows a floating button that opens the panel.
  floatingButton,

  /// Opens the panel from the configured keyboard shortcut.
  keyboardShortcut,
}

/// Runtime mode for [RebuildScanApp].
enum RebuildScanMode {
  /// Disables rebuild tracking.
  off,

  /// Tracks user-code widgets automatically in debug builds only.
  debugAuto,

  /// Tracks only widgets explicitly wrapped by [RebuildScan.mark].
  targeted,
}

/// Count source shown in overlay badges.
enum RebuildBadgeCountMode {
  /// Shows rebuilds within the recent sample window.
  recent,

  /// Shows rebuilds recorded in the latest frame.
  frame,

  /// Shows all rebuilds recorded for the widget entry.
  total,
}

/// Configuration for rebuild tracking, highlighting, and panel behavior.
@immutable
class RebuildScanConfig {
  /// Creates rebuild scan configuration.
  const RebuildScanConfig({
    this.highlightMode = HighlightMode.flash,
    this.badgeCountMode = RebuildBadgeCountMode.recent,
    this.minRebuildsToShow = 1,
    this.ignoreTypes = const <Type>{},
    this.showPanel = true,
    this.panelOpenMethods = const <PanelOpenMethod>{
      PanelOpenMethod.floatingButton,
    },
    this.sampleWindow = const Duration(seconds: 1),
    this.maxEntries = 2000,
    this.trackRects = true,
    this.includeFrameworkWidgetsInAutoScan = false,
  }) : assert(minRebuildsToShow > 0),
       assert(maxEntries > 0);

  /// Highlight style used by the overlay painter.
  final HighlightMode highlightMode;

  /// Count shown inside overlay badges.
  final RebuildBadgeCountMode badgeCountMode;

  /// Minimum recent rebuild count required before an entry is shown.
  final int minRebuildsToShow;

  /// Widget runtime types excluded from tracking.
  final Set<Type> ignoreTypes;

  /// Whether the floating button and panel are available.
  final bool showPanel;

  /// Interactions that can open the panel.
  final Set<PanelOpenMethod> panelOpenMethods;

  /// Sliding window used to compute recent rebuild counts.
  final Duration sampleWindow;

  /// Maximum tracked entries kept before old entries are pruned.
  final int maxEntries;

  /// Whether widget rectangles should be measured for visual highlights.
  final bool trackRects;

  /// Whether debug auto mode should include Flutter framework widgets.
  final bool includeFrameworkWidgetsInAutoScan;

  /// Returns a copy with selected fields replaced.
  RebuildScanConfig copyWith({
    HighlightMode? highlightMode,
    RebuildBadgeCountMode? badgeCountMode,
    int? minRebuildsToShow,
    Set<Type>? ignoreTypes,
    bool? showPanel,
    Set<PanelOpenMethod>? panelOpenMethods,
    Duration? sampleWindow,
    int? maxEntries,
    bool? trackRects,
    bool? includeFrameworkWidgetsInAutoScan,
  }) {
    return RebuildScanConfig(
      highlightMode: highlightMode ?? this.highlightMode,
      badgeCountMode: badgeCountMode ?? this.badgeCountMode,
      minRebuildsToShow: minRebuildsToShow ?? this.minRebuildsToShow,
      ignoreTypes: ignoreTypes ?? this.ignoreTypes,
      showPanel: showPanel ?? this.showPanel,
      panelOpenMethods: panelOpenMethods ?? this.panelOpenMethods,
      sampleWindow: sampleWindow ?? this.sampleWindow,
      maxEntries: maxEntries ?? this.maxEntries,
      trackRects: trackRects ?? this.trackRects,
      includeFrameworkWidgetsInAutoScan:
          includeFrameworkWidgetsInAutoScan ??
          this.includeFrameworkWidgetsInAutoScan,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RebuildScanConfig &&
        other.highlightMode == highlightMode &&
        other.badgeCountMode == badgeCountMode &&
        other.minRebuildsToShow == minRebuildsToShow &&
        setEquals(other.ignoreTypes, ignoreTypes) &&
        other.showPanel == showPanel &&
        setEquals(other.panelOpenMethods, panelOpenMethods) &&
        other.sampleWindow == sampleWindow &&
        other.maxEntries == maxEntries &&
        other.trackRects == trackRects &&
        other.includeFrameworkWidgetsInAutoScan ==
            includeFrameworkWidgetsInAutoScan;
  }

  @override
  int get hashCode {
    return Object.hash(
      highlightMode,
      badgeCountMode,
      minRebuildsToShow,
      Object.hashAll(ignoreTypes),
      showPanel,
      Object.hashAll(panelOpenMethods),
      sampleWindow,
      maxEntries,
      trackRects,
      includeFrameworkWidgetsInAutoScan,
    );
  }
}
