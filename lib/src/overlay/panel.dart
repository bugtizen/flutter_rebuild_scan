// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import '../config.dart';
import '../controller.dart';
import '../models.dart';
import 'panel_widgets.dart';

class ScanPanelPage extends StatelessWidget {
  const ScanPanelPage({
    super.key,
    required this.controller,
    required this.snapshot,
    required this.onClose,
  });

  final RebuildScanController controller;
  final RebuildScanSnapshot snapshot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildTopBar(theme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    PanelStatChip(
                      label: 'Frame',
                      value: '${snapshot.frameNumber}',
                    ),
                    const SizedBox(width: 8),
                    PanelStatChip(
                      label: 'Total',
                      value: '${snapshot.totalRebuilds}',
                    ),
                  ],
                ),
              ),
              _buildControls(),
              Expanded(child: _buildEntries(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Rebuild Scan Panel',
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: controller.clearStats,
            tooltip: 'Clear stats',
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close panel',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final config = snapshot.config;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scanner status'),
                  subtitle: Text(_statusText(snapshot.status)),
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Text('Min rebuilds: ${config.minRebuildsToShow}'),
            ],
          ),
          Slider(
            value: config.minRebuildsToShow.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            label: '${config.minRebuildsToShow}',
            onChanged: (value) {
              controller.setConfig(
                config.copyWith(minRebuildsToShow: value.round()),
              );
            },
          ),
          Row(
            children: <Widget>[
              const Text('Mode'),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<HighlightMode>(
                  showSelectedIcon: false,
                  selected: <HighlightMode>{config.highlightMode},
                  onSelectionChanged: (modes) {
                    controller.setConfig(
                      config.copyWith(highlightMode: modes.single),
                    );
                  },
                  segments: HighlightMode.values
                      .map(
                        (mode) => ButtonSegment<HighlightMode>(
                          value: mode,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(mode.name),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntries(ThemeData theme) {
    if (snapshot.topEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_emptyStateText(snapshot), textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: snapshot.topEntries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = snapshot.topEntries[index];
        final title = entry.name?.isNotEmpty == true
            ? entry.name!
            : entry.widgetType.toString();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: <Widget>[
                  Text('recent ${entry.recentCount}'),
                  Text('frame ${entry.frameCount}'),
                  Text('total ${entry.totalCount}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusText(RebuildScanStatus status) {
    return switch (status) {
      RebuildScanStatus.off => 'Off',
      RebuildScanStatus.active => 'Active',
      RebuildScanStatus.debugAutoUnsupported => 'Debug auto unsupported',
      RebuildScanStatus.noTargets => 'Targeted mode waiting for marks',
    };
  }

  String _emptyStateText(RebuildScanSnapshot snapshot) {
    return switch (snapshot.status) {
      RebuildScanStatus.off => 'Rebuild scan is off.',
      RebuildScanStatus.debugAutoUnsupported =>
        'Auto rebuild tracking is debug-only. Use RebuildScanMode.targeted in profile or release.',
      RebuildScanStatus.noTargets =>
        'No targeted rebuilds recorded. Add RebuildScan.mark(context) inside a widget build.',
      RebuildScanStatus.active => 'No rebuilds recorded in active window.',
    };
  }
}
