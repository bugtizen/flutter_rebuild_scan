import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

/// Mock news feed with filtering, selection and tapped-story Hero details.
class FeedExample extends StatefulWidget {
  const FeedExample({super.key});
  @override
  State<FeedExample> createState() => _FeedExampleState();
}

class _FeedExampleState extends State<FeedExample> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final selectedCount = ValueNotifier(0);
  final selectedIds = <int>{};
  final category = ValueNotifier('For you');
  @override
  void dispose() {
    selectedCount.dispose();
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 570,
    child: Column(
      children: [
        ValueListenableBuilder<String>(
          valueListenable: category,
          builder: (context, current, _) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in const ['For you', 'Flutter', 'Design'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: current == value,
                      onSelected: (_) => category.value = value,
                    ),
                  ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: selectedCount,
          builder: (context, count, _) => Align(
            alignment: Alignment.centerLeft,
            child: Text('$count saved · tap a story to open its detail'),
          ),
        ),
        Expanded(
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _FeedList(
                category: category,
                selectedIds: selectedIds,
                onSelectionChanged: (id, selected) {
                  if (selected) {
                    selectedIds.add(id);
                  } else {
                    selectedIds.remove(id);
                  }
                  selectedCount.value = selectedIds.length;
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Story {
  const _Story(
    this.id,
    this.category,
    this.title,
    this.summary,
    this.icon,
    this.color,
  );
  final int id;
  final String category, title, summary;
  final IconData icon;
  final Color color;
}

const _stories = [
  _Story(
    1,
    'Flutter',
    'Building smoother scrolling feeds',
    'Use stable row state and profile the work that repeats as you scroll.',
    Icons.view_list,
    Colors.teal,
  ),
  _Story(
    2,
    'Design',
    'Making dense screens readable',
    'Small hierarchy changes help readers find the detail they need.',
    Icons.dashboard,
    Colors.deepOrange,
  ),
  _Story(
    3,
    'Flutter',
    'When should a widget rebuild?',
    'Track a useful boundary, then narrow it to the changing value.',
    Icons.refresh,
    Colors.indigo,
  ),
  _Story(
    4,
    'Design',
    'A practical color system',
    'A small palette makes status and emphasis easier to scan.',
    Icons.palette,
    Colors.purple,
  ),
  _Story(
    5,
    'Flutter',
    'Lists with local selection',
    'Keep selection state close to the row for focused updates.',
    Icons.checklist,
    Colors.green,
  ),
  _Story(
    6,
    'Flutter',
    'Measure before optimizing',
    'Counts show where updates happen. Engine timings show frame pressure.',
    Icons.speed,
    Colors.blue,
  ),
  _Story(
    7,
    'Design',
    'Designing a focused detail page',
    'Carry a stable item identity from the feed into the detail route.',
    Icons.article,
    Colors.brown,
  ),
  _Story(
    8,
    'Flutter',
    'Keeping a stream responsive',
    'Receive the full input while coalescing display work per frame.',
    Icons.bolt,
    Colors.amber,
  ),
  _Story(
    9,
    'Design',
    'Accessible loading states',
    'Give asynchronous content a useful label and a stable layout.',
    Icons.accessibility,
    Colors.cyan,
  ),
  _Story(
    10,
    'Flutter',
    'Debug only what you need',
    'Targeted marks keep performance inspection focused.',
    Icons.bug_report,
    Colors.red,
  ),
  _Story(
    11,
    'Design',
    'Navigation that keeps context',
    'Use a shared image to connect a list item with its story.',
    Icons.open_in_new,
    Colors.pink,
  ),
  _Story(
    12,
    'Flutter',
    'Heatmaps with a fixed scale',
    'Compare rebuild activity without rescaling to a changing busiest row.',
    Icons.map,
    Colors.lime,
  ),
];

class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.category,
    required this.selectedIds,
    required this.onSelectionChanged,
  });
  final ValueListenable<String> category;
  final Set<int> selectedIds;
  final void Function(int id, bool selected) onSelectionChanged;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: category,
    builder: (context, selectedCategory, _) {
      final visible = selectedCategory == 'For you'
          ? _stories
          : _stories
                .where((item) => item.category == selectedCategory)
                .toList();
      return ListView.builder(
        key: ValueKey(selectedCategory),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final story = visible[index];
          return _FeedRow(
            key: ValueKey(story.id),
            story: story,
            initiallySelected: selectedIds.contains(story.id),
            onSelectionChanged: (value) => onSelectionChanged(story.id, value),
          );
        },
      );
    },
  );
}

class _FeedRow extends StatefulWidget {
  const _FeedRow({
    super.key,
    required this.story,
    required this.initiallySelected,
    required this.onSelectionChanged,
  });
  final _Story story;
  final bool initiallySelected;
  final ValueChanged<bool> onSelectionChanged;
  @override
  State<_FeedRow> createState() => _FeedRowState();
}

class _FeedRowState extends State<_FeedRow> {
  late bool selected = widget.initiallySelected;
  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    RebuildScan.mark(context, name: 'Feed row ${story.id}', tag: 'feed-row');
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _StoryDetail(story: story),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'story-${story.id}',
                  child: Container(
                    width: 72,
                    height: 72,
                    color: story.color.withValues(alpha: .15),
                    child: Icon(story.icon, size: 38, color: story.color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.category.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          story.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          story.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          CheckboxListTile(
            dense: true,
            title: const Text('Save for later'),
            value: selected,
            onChanged: (value) {
              final next = value ?? false;
              setState(() => selected = next);
              widget.onSelectionChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _StoryDetail extends StatelessWidget {
  const _StoryDetail({required this.story});
  final _Story story;
  @override
  Widget build(BuildContext context) {
    RebuildScan.mark(context, name: 'Feed story detail');
    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Hero(
            tag: 'story-${story.id}',
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: story.color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(story.icon, size: 92, color: story.color),
            ),
          ),
          const SizedBox(height: 20),
          Text(story.category, style: Theme.of(context).textTheme.labelLarge),
          Text(story.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(story.summary),
          const SizedBox(height: 12),
          Text(
            '${story.summary} ${story.summary}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to feed'),
          ),
        ],
      ),
    );
  }
}
