// ignore_for_file: public_member_api_docs

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../controller.dart';
import '../models.dart';
import '../frame_metrics.dart';
import 'painter.dart';
import 'panel.dart';

class ScanOverlayEntry extends StatefulWidget {
  const ScanOverlayEntry({super.key, required this.controller});

  final RebuildScanController controller;

  @override
  State<ScanOverlayEntry> createState() => _ScanOverlayEntryState();
}

class _ScanOverlayEntryState extends State<ScanOverlayEntry> {
  bool _isPanelOpen = false;
  double _panelBottom = 8;
  OverlayEntry? _entry;
  RebuildScanHighlightPainter? _painter;
  @override
  void didUpdateWidget(covariant ScanOverlayEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _painter?.disposeResources();
      _painter = null;
      _entry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _painter?.disposeResources();
    super.dispose();
  }

  void _togglePanel() {
    setState(() {
      _isPanelOpen = !_isPanelOpen;
    });
    _entry?.markNeedsBuild();
  }

  void _closePanel() {
    if (!_isPanelOpen) {
      return;
    }
    setState(() {
      _isPanelOpen = false;
    });
    _entry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: <OverlayEntry>[
        _entry ??= OverlayEntry(
          builder: (context) {
            return ValueListenableBuilder<int>(
              valueListenable: widget.controller.settingsRevision,
              builder: (context, revision, _) {
                final snapshot = widget.controller.snapshot;
                if (!snapshot.config.showPanel) {
                  _isPanelOpen = false;
                }

                final methods = snapshot.config.panelOpenMethods;
                final supportsKeyboard = methods.contains(
                  PanelOpenMethod.keyboardShortcut,
                );
                final supportsFab = methods.contains(
                  PanelOpenMethod.floatingButton,
                );

                Widget overlayTree = Stack(
                  alignment: Alignment.topLeft,
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _painter ??= RebuildScanHighlightPainter(
                              controller: widget.controller,
                              origin: () {
                                final render = context.findRenderObject();
                                return render is RenderBox
                                    ? render.localToGlobal(Offset.zero)
                                    : Offset.zero;
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (snapshot.config.showPerformanceOverlay)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: IgnorePointer(
                          child: PerformanceOverlay.allEnabled(),
                        ),
                      ),
                    if (snapshot.config.showFrameMonitor)
                      Positioned(
                        top: 24,
                        left: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: Material(
                            child: ValueListenableBuilder<FrameMetricsSnapshot>(
                              valueListenable: widget.controller.frameMetrics,
                              builder: (context, metrics, _) => Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  'Engine ${metrics.completedFrames} · last ${metrics.framesPerSecond?.toStringAsFixed(0) ?? "—"} fps · UI p95 ${(metrics.uiP95.inMicroseconds / 1000).toStringAsFixed(2)} ms · raster ${(metrics.rasterP95.inMicroseconds / 1000).toStringAsFixed(2)} ms',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (snapshot.config.showPanel &&
                        supportsFab &&
                        !_isPanelOpen)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'scan_panel_fab',
                          onPressed: _togglePanel,
                          child: const Icon(Icons.analytics_outlined),
                        ),
                      ),
                    if (snapshot.config.showPanel && _isPanelOpen)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: _panelBottom,
                        height:
                            (MediaQuery.maybeSizeOf(context)?.height ??
                                View.of(context).physicalSize.height /
                                    View.of(context).devicePixelRatio) *
                            .4,
                        child: ValueListenableBuilder<RebuildScanSnapshot>(
                          valueListenable: widget.controller.listenable,
                          builder: (context, latest, _) => ScanPanelPage(
                            controller: widget.controller,
                            snapshot: latest,
                            onClose: _closePanel,
                            onDrag: (details) {
                              final height =
                                  View.of(context).physicalSize.height /
                                  View.of(context).devicePixelRatio;
                              _panelBottom = (_panelBottom - details.delta.dy)
                                  .clamp(
                                    8.0,
                                    (height * .6 - 8).clamp(
                                      8.0,
                                      double.infinity,
                                    ),
                                  );
                              _entry?.markNeedsBuild();
                            },
                          ),
                        ),
                      ),
                  ],
                );

                if (snapshot.config.showPanel && supportsKeyboard) {
                  overlayTree = Focus(
                    autofocus: true,
                    child: Shortcuts(
                      shortcuts: const <ShortcutActivator, Intent>{
                        SingleActivator(
                          LogicalKeyboardKey.keyJ,
                          control: true,
                          shift: true,
                        ): _TogglePanelIntent(),
                        SingleActivator(
                          LogicalKeyboardKey.keyJ,
                          meta: true,
                          shift: true,
                        ): _TogglePanelIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          _TogglePanelIntent:
                              CallbackAction<_TogglePanelIntent>(
                                onInvoke: (intent) {
                                  _togglePanel();
                                  return null;
                                },
                              ),
                        },
                        child: overlayTree,
                      ),
                    ),
                  );
                }

                return Theme(
                  data: Theme.of(context),
                  child: Localizations(
                    locale: const Locale('en', 'US'),
                    delegates: const <LocalizationsDelegate<dynamic>>[
                      DefaultWidgetsLocalizations.delegate,
                      DefaultMaterialLocalizations.delegate,
                      DefaultCupertinoLocalizations.delegate,
                    ],
                    child: overlayTree,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _TogglePanelIntent extends Intent {
  const _TogglePanelIntent();
}
