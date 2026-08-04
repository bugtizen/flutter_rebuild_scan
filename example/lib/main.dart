import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

const String _exampleMode = String.fromEnvironment(
  'REBUILD_SCAN_EXAMPLE_MODE',
  defaultValue: 'targeted',
);

void main() {
  if (_exampleMode == 'debugAuto') {
    runDebugAutoExample();
    return;
  }

  runTargetedExample();
}

void runTargetedExample() {
  runApp(
    const RebuildScanApp(
      mode: RebuildScanMode.targeted,
      config: RebuildScanConfig(
        showPanel: true,
        highlightMode: HighlightMode.flash,
        sampleWindow: Duration(seconds: 1),
        // ignoreTypes: {Scaffold},
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RebuildDemoPage(
          title: 'Targeted Rebuild Demo',
          markTargets: true,
        ),
      ),
    ),
  );
}

void runDebugAutoExample() {
  runApp(
    const RebuildScanApp(
      mode: RebuildScanMode.debugAuto,
      config: RebuildScanConfig(
        showPanel: true,
        highlightMode: HighlightMode.flash,
        sampleWindow: Duration(seconds: 1),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RebuildDemoPage(
          title: 'Debug Auto Rebuild Demo',
          markTargets: false,
        ),
      ),
    ),
  );
}

class RebuildDemoPage extends StatefulWidget {
  const RebuildDemoPage({
    super.key,
    required this.title,
    required this.markTargets,
  });

  final String title;
  final bool markTargets;

  @override
  State<RebuildDemoPage> createState() => _RebuildDemoPageState();
}

class _RebuildDemoPageState extends State<RebuildDemoPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<_RowData> _allRows = List<_RowData>.generate(
    120,
    (index) => _RowData(
      id: index,
      title: 'Row $index',
      category: 'Group ${index % 6}',
    ),
  );

  late final Map<int, ValueNotifier<bool>> _rowSelection;
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  final ValueNotifier<bool> _liveUpdates = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _onlyEven = ValueNotifier<bool>(false);
  final ValueNotifier<String> _query = ValueNotifier<String>('');
  final ValueNotifier<int> _selectedCount = ValueNotifier<int>(0);

  late final Timer _timer;

  @override
  void initState() {
    super.initState();

    _rowSelection = <int, ValueNotifier<bool>>{
      for (final row in _allRows) row.id: ValueNotifier<bool>(false),
    };

    _searchController.addListener(() {
      final nextQuery = _searchController.text.trim().toLowerCase();
      if (_query.value != nextQuery) {
        _query.value = nextQuery;
      }
    });

    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!_liveUpdates.value) {
        return;
      }
      _tick.value = _tick.value + 1;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    _tick.dispose();
    _liveUpdates.dispose();
    _onlyEven.dispose();
    _query.dispose();
    _selectedCount.dispose();
    for (final notifier in _rowSelection.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  void _toggleSelection(int rowId) {
    final selectionNotifier = _rowSelection[rowId]!;
    final wasSelected = selectionNotifier.value;
    selectionNotifier.value = !wasSelected;
    _selectedCount.value = _selectedCount.value + (wasSelected ? -1 : 1);
  }

  void _clearSelection() {
    var cleared = 0;
    for (final notifier in _rowSelection.values) {
      if (notifier.value) {
        notifier.value = false;
        cleared += 1;
      }
    }
    if (cleared > 0) {
      _selectedCount.value = 0;
    }
  }

  void _burstTick() {
    _tick.value = _tick.value + 5;
  }

  @override
  Widget build(BuildContext context) {
    _markTarget(context, 'RebuildDemoPage', enabled: widget.markTargets);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _liveUpdates,
            builder: (context, isLive, _) {
              _markTarget(
                context,
                'LiveToggleAction',
                enabled: widget.markTargets,
              );

              return IconButton(
                onPressed: () => _liveUpdates.value = !isLive,
                icon: Icon(isLive ? Icons.pause : Icons.play_arrow),
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetailsPage(
                    seed: _tick.value,
                    markTargets: widget.markTargets,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _StatsHeader(
            rows: _allRows,
            tick: _tick,
            onlyEven: _onlyEven,
            query: _query,
            selectedCount: _selectedCount,
            markTargets: widget.markTargets,
          ),
          _FilterBar(
            controller: _searchController,
            onlyEven: _onlyEven,
            markTargets: widget.markTargets,
          ),
          Expanded(
            child: _ResultsList(
              rows: _allRows,
              query: _query,
              onlyEven: _onlyEven,
              rowSelection: _rowSelection,
              onToggleSelection: _toggleSelection,
              markTargets: widget.markTargets,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _clearSelection,
                    child: const Text('Clear selection'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _burstTick,
                    child: const Text('Burst +5 tick'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.rows,
    required this.tick,
    required this.onlyEven,
    required this.query,
    required this.selectedCount,
    required this.markTargets,
  });

  final List<_RowData> rows;
  final ValueListenable<int> tick;
  final ValueListenable<bool> onlyEven;
  final ValueListenable<String> query;
  final ValueListenable<int> selectedCount;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    _markTarget(context, 'StatsHeader', enabled: markTargets);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.blueGrey.shade50,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _TickChip(tick: tick, markTargets: markTargets),
          _VisibleCountChip(
            rows: rows,
            query: query,
            onlyEven: onlyEven,
            markTargets: markTargets,
          ),
          _SelectedCountChip(
            selectedCount: selectedCount,
            markTargets: markTargets,
          ),
        ],
      ),
    );
  }
}

class _TickChip extends StatelessWidget {
  const _TickChip({required this.tick, required this.markTargets});

  final ValueListenable<int> tick;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tick: '),
          ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, value, _) {
              _markTarget(context, 'TickValue', enabled: markTargets);

              return Text('$value');
            },
          ),
        ],
      ),
    );
  }
}

class _VisibleCountChip extends StatelessWidget {
  const _VisibleCountChip({
    required this.rows,
    required this.query,
    required this.onlyEven,
    required this.markTargets,
  });

  final List<_RowData> rows;
  final ValueListenable<String> query;
  final ValueListenable<bool> onlyEven;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[query, onlyEven]),
      builder: (context, _) {
        _markTarget(context, 'VisibleCountChip', enabled: markTargets);

        final visibleCount = rows
            .where((row) => _matchesFilter(row, query.value, onlyEven.value))
            .length;

        return Chip(label: Text('Visible: $visibleCount'));
      },
    );
  }
}

class _SelectedCountChip extends StatelessWidget {
  const _SelectedCountChip({
    required this.selectedCount,
    required this.markTargets,
  });

  final ValueListenable<int> selectedCount;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedCount,
      builder: (context, value, _) {
        _markTarget(context, 'SelectedCountChip', enabled: markTargets);

        return Chip(label: Text('Selected: $value'));
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.onlyEven,
    required this.markTargets,
  });

  final TextEditingController controller;
  final ValueNotifier<bool> onlyEven;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    _markTarget(context, 'FilterBar', enabled: markTargets);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Search rows',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: ValueListenableBuilder<bool>(
              valueListenable: onlyEven,
              builder: (context, value, _) {
                _markTarget(context, 'OnlyEvenSwitch', enabled: markTargets);

                return SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Only even'),
                  value: value,
                  onChanged: (next) => onlyEven.value = next,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.rows,
    required this.query,
    required this.onlyEven,
    required this.rowSelection,
    required this.onToggleSelection,
    required this.markTargets,
  });

  final List<_RowData> rows;
  final ValueListenable<String> query;
  final ValueListenable<bool> onlyEven;
  final Map<int, ValueNotifier<bool>> rowSelection;
  final void Function(int rowId) onToggleSelection;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[query, onlyEven]),
      builder: (context, _) {
        _markTarget(context, 'ResultsList', enabled: markTargets);

        final visibleRows = rows
            .where((row) => _matchesFilter(row, query.value, onlyEven.value))
            .toList(growable: false);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: visibleRows.length,
          itemBuilder: (context, index) {
            final row = visibleRows[index];
            return _RowTile(
              row: row,
              selected: rowSelection[row.id]!,
              onToggle: () => onToggleSelection(row.id),
              markTargets: markTargets,
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 6),
        );
      },
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.row,
    required this.selected,
    required this.onToggle,
    required this.markTargets,
  });

  final _RowData row;
  final ValueListenable<bool> selected;
  final VoidCallback onToggle;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: selected,
      builder: (context, isSelected, _) {
        _markTarget(context, 'RowTile ${row.id}', enabled: markTargets);

        return ListTile(
          tileColor: isSelected ? Colors.amber.shade50 : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(row.title),
          subtitle: Text(row.category),
          trailing: IconButton(
            onPressed: onToggle,
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
          ),
          onTap: onToggle,
        );
      },
    );
  }
}

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key, required this.seed, required this.markTargets});

  final int seed;
  final bool markTargets;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late final Timer _timer;
  final ValueNotifier<int> _pulse = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _pulse.value = widget.seed;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pulse.value = _pulse.value + 1;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _markTarget(context, 'DetailsPage', enabled: widget.markTargets);

    return Scaffold(
      appBar: AppBar(title: const Text('Details Page')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 30,
        itemBuilder: (context, index) {
          return _PulseCard(
            index: index,
            pulse: _pulse,
            markTargets: widget.markTargets,
          );
        },
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({
    required this.index,
    required this.pulse,
    required this.markTargets,
  });

  final int index;
  final ValueListenable<int> pulse;
  final bool markTargets;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pulse,
      child: ListTile(title: Text('Card $index')),
      builder: (context, value, child) {
        _markTarget(context, 'PulseCard $index', enabled: markTargets);

        final hue = (value * 13 + index * 17) % 360;
        final color = HSVColor.fromAHSV(1, hue.toDouble(), 0.2, 0.95).toColor();
        return Card(
          color: color,
          child: ListTile(
            title: child,
            subtitle: Text('pulse $value • hue $hue'),
          ),
        );
      },
    );
  }
}

void _markTarget(BuildContext context, String name, {required bool enabled}) {
  if (!enabled) {
    return;
  }
  RebuildScan.mark(context, name: name);
}

bool _matchesFilter(_RowData row, String query, bool onlyEven) {
  if (onlyEven && row.id.isOdd) {
    return false;
  }
  if (query.isEmpty) {
    return true;
  }
  final lowerTitle = row.title.toLowerCase();
  final lowerCategory = row.category.toLowerCase();
  return lowerTitle.contains(query) || lowerCategory.contains(query);
}

class _RowData {
  const _RowData({
    required this.id,
    required this.title,
    required this.category,
  });

  final int id;
  final String title;
  final String category;
}
