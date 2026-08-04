// ignore_for_file: public_member_api_docs

import 'package:flutter/scheduler.dart';

typedef FrameEndCallback = void Function(int frameNumber);

class FrameTracker {
  FrameTracker({required this.onFrameEnd});

  final FrameEndCallback onFrameEnd;

  bool _running = false;
  int _frameNumber = 0;

  int get currentFrame => _frameNumber;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _scheduleNext();
  }

  void stop() {
    _running = false;
  }

  void _scheduleNext() {
    if (!_running) {
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_running) {
        return;
      }

      _frameNumber += 1;
      onFrameEnd(_frameNumber);
      _scheduleNext();
    });
  }
}
