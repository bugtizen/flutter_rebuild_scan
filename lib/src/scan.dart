import 'package:flutter/material.dart';

import 'controller.dart';
import 'scan_scope.dart';

/// Utilities for targeted rebuild tracking.
abstract final class RebuildScan {
  /// Records a rebuild for the widget whose [context] is currently building.
  ///
  /// This is intended for [RebuildScanMode.targeted]. It records the counter
  /// immediately and queues rectangle measurement for the end of the frame.
  static void mark(BuildContext context, {String? name, Object? tag}) {
    final scope = ScanScope.maybeOf(context);
    if (scope == null ||
        !scope.instrumentationEnabled ||
        !scope.manualScanEnabled) {
      return;
    }

    final element = context as Element;
    final controller = scope.controller;
    final widgetType = element.widget.runtimeType;
    final id = identityHashCode(element);

    controller.recordRebuild(
      id: id,
      name: name ?? widgetType.toString(),
      tag: tag,
      widgetType: widgetType,
    );

    controller.queueRectMeasurement(id: id, element: element);
  }
}

/// Widget boundary that records rebuilds of the boundary itself.
///
/// This does not observe every descendant rebuild. Prefer [RebuildScan.mark]
/// inside the widget build method when measuring a specific widget.
class RebuildScanBoundary extends StatefulWidget {
  /// Creates a rebuild scan boundary around [child].
  const RebuildScanBoundary({
    super.key,
    required this.child,
    this.name,
    this.tag,
    this.enabled = true,
  });

  /// Child rendered by this boundary.
  final Widget child;

  /// Human-readable name shown in the panel.
  final String? name;

  /// Optional caller-provided grouping tag.
  final Object? tag;

  /// Whether this boundary should record rebuilds.
  final bool enabled;

  @override
  State<RebuildScanBoundary> createState() => _RebuildScanBoundaryState();
}

class _RebuildScanBoundaryState extends State<RebuildScanBoundary> {
  late final int _id = identityHashCode(this);
  RebuildScanController? _boundController;

  @override
  void dispose() {
    _boundController?.markDisposed(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final scope = ScanScope.maybeOf(context);
    if (scope == null ||
        !scope.instrumentationEnabled ||
        !scope.manualScanEnabled) {
      return widget.child;
    }

    final controller = scope.controller;
    _boundController = controller;

    controller.recordRebuild(
      id: _id,
      name: widget.name,
      tag: widget.tag,
      widgetType: widget.child.runtimeType,
    );

    controller.queueRectMeasurement(id: _id, element: context as Element);

    return widget.child;
  }
}
