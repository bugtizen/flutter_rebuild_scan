import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'controller.dart';
import 'scan_scope.dart';
import 'utils/rect_utils.dart';

abstract final class RebuildScan {
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

    if (controller.config.trackRects) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!element.mounted) {
          return;
        }
        controller.updateRect(id: id, rect: RectUtils.getGlobalRect(element));
      });
    }
  }
}

class RebuildScanBoundary extends StatefulWidget {
  const RebuildScanBoundary({
    super.key,
    required this.child,
    this.name,
    this.tag,
    this.enabled = true,
  });

  final Widget child;
  final String? name;
  final Object? tag;
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

    if (controller.config.trackRects) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        controller.updateRect(id: _id, rect: RectUtils.getGlobalRect(context));
      });
    }

    return widget.child;
  }
}
