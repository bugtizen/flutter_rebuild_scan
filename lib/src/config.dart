import 'package:flutter/foundation.dart';

enum HighlightMode { flash, heatmap, outline }

enum PanelOpenMethod { floatingButton, keyboardShortcut }

enum RebuildScanMode { off, debugAuto, targeted }

enum RebuildBadgeCountMode { recent, frame, total }

@immutable
class RebuildScanConfig {
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

  final HighlightMode highlightMode;
  final RebuildBadgeCountMode badgeCountMode;
  final int minRebuildsToShow;
  final Set<Type> ignoreTypes;
  final bool showPanel;
  final Set<PanelOpenMethod> panelOpenMethods;
  final Duration sampleWindow;
  final int maxEntries;
  final bool trackRects;
  final bool includeFrameworkWidgetsInAutoScan;

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
