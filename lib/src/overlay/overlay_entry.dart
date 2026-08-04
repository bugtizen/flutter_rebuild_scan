import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../controller.dart';
import '../models.dart';
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

  void _togglePanel() {
    setState(() {
      _isPanelOpen = !_isPanelOpen;
    });
  }

  void _closePanel() {
    if (!_isPanelOpen) {
      return;
    }
    setState(() {
      _isPanelOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: <OverlayEntry>[
        OverlayEntry(
          builder: (context) {
            return ValueListenableBuilder<RebuildScanSnapshot>(
              valueListenable: widget.controller.listenable,
              builder: (context, snapshot, _) {
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
                            painter: RebuildScanHighlightPainter(
                              snapshot: snapshot,
                              nowMicros: DateTime.now().microsecondsSinceEpoch,
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
                      ScanPanelPage(
                        controller: widget.controller,
                        snapshot: snapshot,
                        onClose: _closePanel,
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
