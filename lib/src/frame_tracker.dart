// ignore_for_file: public_member_api_docs
import 'package:flutter/scheduler.dart';

typedef FrameEndCallback = void Function(int frameNumber);

class FrameTracker {
  FrameTracker({required this.onFrameEnd});
  final FrameEndCallback onFrameEnd;
  int? _callback;
  int _generation = 0;
  bool _running = false;
  int _frameNumber = 0;
  int get currentFrame => _frameNumber;
  void start() {
    if (_running) return;
    _running = true;
    _schedule(_generation);
  }

  void stop() {
    _running = false;
    _generation++;
    if (_callback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_callback!);
    }
    _callback = null;
  }

  void _schedule(int generation) {
    _callback = SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!_running || generation != _generation) return;
      _callback = null;
      onFrameEnd(++_frameNumber);
      if (_running && generation == _generation) _schedule(generation);
    }, scheduleNewFrame: false);
  }
}
