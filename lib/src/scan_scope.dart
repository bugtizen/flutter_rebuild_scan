import 'package:flutter/widgets.dart';

import 'controller.dart';

class ScanScope extends InheritedWidget {
  const ScanScope({
    super.key,
    required this.controller,
    required this.instrumentationEnabled,
    required this.manualScanEnabled,
    required super.child,
  });

  final RebuildScanController controller;
  final bool instrumentationEnabled;
  final bool manualScanEnabled;

  static ScanScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScanScope>();
  }

  @override
  bool updateShouldNotify(ScanScope oldWidget) {
    return oldWidget.controller != controller ||
        oldWidget.instrumentationEnabled != instrumentationEnabled ||
        oldWidget.manualScanEnabled != manualScanEnabled;
  }
}
