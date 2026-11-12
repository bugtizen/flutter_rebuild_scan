import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

/// Local mock input. No sockets, network access or backend process.
class MockFeedExample extends StatefulWidget {
  const MockFeedExample({super.key});
  @override
  State<MockFeedExample> createState() => _MockFeedExampleState();
}

class _MockFeedExampleState extends State<MockFeedExample> {
  final display = ValueNotifier(0);
  Timer? timer;
  int? pendingFrame;
  int inputs = 0, notifications = 0, builds = 0;
  bool coalesce = true;

  void publish() {
    notifications++;
    display.value = inputs;
  }

  void stop() {
    timer?.cancel();
    timer = null;
    if (pendingFrame != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(pendingFrame!);
    }
    pendingFrame = null;
  }

  void toggle() => setState(() {
    if (timer != null) {
      stop();
      return;
    }
    // Ten logical inputs per 10 ms tick: a 1,000/sec target, not a clock guarantee.
    timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      for (var i = 0; i < 10; i++) {
        inputs++;
        if (!coalesce) {
          publish();
          continue;
        }
        pendingFrame ??= SchedulerBinding.instance.scheduleFrameCallback((_) {
          pendingFrame = null;
          publish();
        });
      }
    });
  });
  @override
  void dispose() {
    stop();
    display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FilledButton(
        onPressed: toggle,
        child: Text(timer == null ? 'Start mock feed' : 'Pause mock feed'),
      ),
      SwitchListTile(
        title: const Text('Coalesce display notifications'),
        value: coalesce,
        onChanged: (value) => setState(() {
          if (pendingFrame != null) {
            SchedulerBinding.instance.cancelFrameCallbackWithId(pendingFrame!);
          }
          pendingFrame = null;
          coalesce = value;
        }),
      ),
      ValueListenableBuilder<int>(
        valueListenable: display,
        builder: (context, value, child) {
          builds++;
          RebuildScan.mark(context, name: 'Mock feed display');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Inputs: $inputs\nDisplay notifications: $notifications\nDisplay builds: $builds\nLatest displayed input: $value',
                key: const ValueKey('feed-summary'),
              ),
            ),
          );
        },
      ),
      const Text(
        'Target: 1,000 mock inputs/sec. Timer scheduling varies by device. The performance preset counts builds but disables highlights. Engine frame counts appear in the monitor.',
      ),
    ],
  );
}
