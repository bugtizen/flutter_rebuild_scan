/// Rebuild diagnostics for Flutter widget trees.
///
/// Use [RebuildScanApp] at the root of an app, then choose either
/// [RebuildScanMode.debugAuto] for debug-only automatic tracking or
/// [RebuildScanMode.targeted] with [RebuildScan.mark] for explicit tracking.
library;

export 'src/config.dart';
export 'src/controller.dart';
export 'src/models.dart' hide RebuildEntry, RebuildEvent;
export 'src/scan.dart';
export 'src/scan_app.dart' hide debugResolveRebuildScanStatus;
