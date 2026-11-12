import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

/// Put the mark in the widget being measured, not its parent builder.
class CounterTile extends StatefulWidget {
  const CounterTile({super.key, required this.name, this.mark = true});
  final String name;
  final bool mark;
  @override
  State<CounterTile> createState() => _CounterTileState();
}

class _CounterTileState extends State<CounterTile> {
  int value = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.mark) RebuildScan.mark(context, name: widget.name);
    return Card(
      child: ListTile(
        title: Text(widget.name),
        subtitle: Text('Value: $value'),
        trailing: IconButton(
          tooltip: 'Increment ${widget.name}',
          icon: const Icon(Icons.add),
          onPressed: () => setState(() => value++),
        ),
      ),
    );
  }
}

class TargetedExample extends StatelessWidget {
  const TargetedExample({super.key, required this.controller});
  final RebuildScanController controller;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const CounterTile(name: 'Counter'),
      const SizedBox(height: 12),
      ValueListenableBuilder<int>(
        valueListenable: controller.settingsRevision,
        builder: (context, _, child) =>
            DropdownButtonFormField<RebuildBadgeCountMode>(
              initialValue: controller.config.badgeCountMode,
              decoration: const InputDecoration(
                labelText: 'Badge count source',
              ),
              items: [
                for (final mode in RebuildBadgeCountMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.name)),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  controller.setConfig(
                    controller.config.copyWith(badgeCountMode: mode),
                  );
                }
              },
            ),
      ),
    ],
  );
}

class BoundaryExample extends StatefulWidget {
  const BoundaryExample({super.key});
  @override
  State<BoundaryExample> createState() => _BoundaryExampleState();
}

class _BoundaryExampleState extends State<BoundaryExample> {
  int refreshes = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RebuildScanBoundary(
        name: 'Boundary',
        tag: refreshes,
        child: const CounterTile(name: 'Child (unmarked)', mark: false),
      ),
      FilledButton(
        onPressed: () => setState(() => refreshes++),
        child: Text('Refresh boundary ($refreshes)'),
      ),
    ],
  );
}

class ListRowsExample extends StatelessWidget {
  const ListRowsExample({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      CounterTile(name: 'Row 1'),
      CounterTile(name: 'Row 2'),
      CounterTile(name: 'Row 3'),
    ],
  );
}

class IgnoredCounter extends StatefulWidget {
  const IgnoredCounter({super.key});
  @override
  State<IgnoredCounter> createState() => _IgnoredCounterState();
}

class _IgnoredCounterState extends State<IgnoredCounter> {
  int value = 0;
  @override
  Widget build(BuildContext context) {
    RebuildScan.mark(context, name: 'Filtered counter');
    return Card(
      child: ListTile(
        title: const Text('Filtered counter'),
        subtitle: Text('Value: $value'),
        trailing: IconButton(
          tooltip: 'Increment filtered counter',
          icon: const Icon(Icons.add),
          onPressed: () => setState(() => value++),
        ),
      ),
    );
  }
}

class ControlsExample extends StatelessWidget {
  const ControlsExample({super.key, required this.controller});
  final RebuildScanController controller;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const CounterTile(name: 'Included counter'),
      const IgnoredCounter(),
      ValueListenableBuilder<int>(
        valueListenable: controller.settingsRevision,
        builder: (context, _, child) {
          final config = controller.config;
          return Column(
            children: [
              SwitchListTile(
                title: const Text('Ignore filtered counter'),
                value: config.ignoreTypes.contains(IgnoredCounter),
                onChanged: (value) => controller.setConfig(
                  config.copyWith(ignoreTypes: value ? {IgnoredCounter} : {}),
                ),
              ),
              DropdownButtonFormField<HighlightMode>(
                initialValue: config.highlightMode,
                decoration: const InputDecoration(labelText: 'Highlight mode'),
                items: [
                  for (final mode in HighlightMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.name)),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    controller.setConfig(config.copyWith(highlightMode: mode));
                  }
                },
              ),
              Text('Minimum recent rebuilds: ${config.minRebuildsToShow}'),
              Slider(
                value: config.minRebuildsToShow.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                onChanged: (value) => controller.setConfig(
                  config.copyWith(minRebuildsToShow: value.round()),
                ),
              ),
            ],
          );
        },
      ),
      OutlinedButton(
        onPressed: controller.clearStats,
        child: const Text('Clear scanner stats'),
      ),
    ],
  );
}
