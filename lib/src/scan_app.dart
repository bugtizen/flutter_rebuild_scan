import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'controller.dart';
import 'models.dart';
import 'overlay/overlay_entry.dart';
import 'scan_scope.dart';
import 'utils/rect_utils.dart';

class RebuildScanApp extends StatefulWidget {
  const RebuildScanApp({
    super.key,
    required this.child,
    this.mode = kDebugMode ? RebuildScanMode.debugAuto : RebuildScanMode.off,
    this.config,
    this.controller,
  });

  final Widget child;
  final RebuildScanMode mode;
  final RebuildScanConfig? config;
  final RebuildScanController? controller;

  @override
  State<RebuildScanApp> createState() => _ScanAppState();
}

class _ScanAppState extends State<RebuildScanApp> {
  late RebuildScanController _controller;
  late bool _ownsController;
  bool _autoScanHookInstalled = false;

  _ResolvedScanMode get _resolvedMode => _resolveMode(widget.mode);

  @override
  void initState() {
    super.initState();
    _initController();
    _syncAutoScanHook();
  }

  @override
  void didUpdateWidget(covariant RebuildScanApp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _controller.detach();
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      _syncAutoScanHook();
      return;
    }

    if (widget.config != null && widget.config != oldWidget.config) {
      _controller.setConfig(widget.config!);
    }

    final resolved = _resolvedMode;
    _controller.setMode(mode: resolved.mode, status: resolved.status);

    _syncAutoScanHook();
  }

  @override
  void dispose() {
    _removeAutoScanHook();
    _controller.detach();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _syncAutoScanHook() {
    final shouldInstall =
        _controller.isEnabled && _controller.mode == RebuildScanMode.debugAuto;
    if (shouldInstall && !_autoScanHookInstalled) {
      _AutoScanHookManager.register(this);
      _autoScanHookInstalled = true;
    } else if (!shouldInstall && _autoScanHookInstalled) {
      _removeAutoScanHook();
    }
  }

  void _removeAutoScanHook() {
    if (!_autoScanHookInstalled) {
      return;
    }

    _AutoScanHookManager.unregister(this);
    _autoScanHookInstalled = false;
  }

  void _recordAutoRebuild(Element element) {
    if (!_controller.isEnabled) {
      return;
    }

    final scanScopeElement = element
        .getElementForInheritedWidgetOfExactType<ScanScope>();
    if (scanScopeElement == null) {
      return;
    }

    final scopeWidget = scanScopeElement.widget;
    if (scopeWidget is! ScanScope ||
        !scopeWidget.instrumentationEnabled ||
        scopeWidget.controller != _controller) {
      return;
    }

    final id = identityHashCode(element);
    final rebuiltWidget = element.widget;
    if (!_controller.config.includeFrameworkWidgetsInAutoScan &&
        !debugIsWidgetLocalCreation(rebuiltWidget)) {
      return;
    }

    _controller.recordRebuild(
      id: id,
      name: rebuiltWidget.runtimeType.toString(),
      widgetType: rebuiltWidget.runtimeType,
    );

    if (_controller.config.trackRects) {
      _controller.updateRect(id: id, rect: RectUtils.getGlobalRect(element));
    }
  }

  void _initController() {
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        RebuildScanController(
          config: widget.config ?? const RebuildScanConfig(),
          mode: _resolvedMode.mode,
          status: _resolvedMode.status,
        );

    if (widget.config != null) {
      _controller.setConfig(widget.config!);
    }

    final resolved = _resolvedMode;
    _controller.setMode(mode: resolved.mode, status: resolved.status);

    _controller.attach();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.status == RebuildScanStatus.off) {
      return widget.child;
    }

    final scannerTree = ScanScope(
      controller: _controller,
      instrumentationEnabled: _controller.isEnabled,
      manualScanEnabled: _controller.mode == RebuildScanMode.targeted,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          ScanScope(
            controller: _controller,
            instrumentationEnabled: false,
            manualScanEnabled: false,
            child: ScanOverlayEntry(controller: _controller),
          ),
        ],
      ),
    );

    if (Directionality.maybeOf(context) != null) {
      return scannerTree;
    }

    return Directionality(textDirection: TextDirection.ltr, child: scannerTree);
  }
}

_ResolvedScanMode _resolveMode(RebuildScanMode mode) {
  return _ResolvedScanMode(
    mode: mode,
    status: debugResolveRebuildScanStatus(mode, debugMode: kDebugMode),
  );
}

@visibleForTesting
RebuildScanStatus debugResolveRebuildScanStatus(
  RebuildScanMode mode, {
  required bool debugMode,
}) {
  return switch (mode) {
    RebuildScanMode.off => RebuildScanStatus.off,
    RebuildScanMode.debugAuto when debugMode => RebuildScanStatus.active,
    RebuildScanMode.debugAuto => RebuildScanStatus.debugAutoUnsupported,
    RebuildScanMode.targeted => RebuildScanStatus.noTargets,
  };
}

class _ResolvedScanMode {
  const _ResolvedScanMode({required this.mode, required this.status});

  final RebuildScanMode mode;
  final RebuildScanStatus status;
}

class _AutoScanHookManager {
  static final Set<_ScanAppState> _states = <_ScanAppState>{};
  static RebuildDirtyWidgetCallback? _previousCallback;

  static void register(_ScanAppState state) {
    _states.add(state);
    if (_states.length == 1) {
      _previousCallback = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = _handleRebuild;
    }
  }

  static void unregister(_ScanAppState state) {
    _states.remove(state);
    if (_states.isEmpty && debugOnRebuildDirtyWidget == _handleRebuild) {
      debugOnRebuildDirtyWidget = _previousCallback;
      _previousCallback = null;
    }
  }

  static void _handleRebuild(Element element, bool builtOnce) {
    _previousCallback?.call(element, builtOnce);
    for (final state in List<_ScanAppState>.of(_states)) {
      state._recordAutoRebuild(element);
    }
  }
}
