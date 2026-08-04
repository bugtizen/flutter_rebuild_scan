class Throttler {
  Throttler(this.interval);

  final Duration interval;
  int _lastTickMicros = 0;

  bool shouldRun({required int nowMicros}) {
    if (_lastTickMicros == 0 ||
        nowMicros - _lastTickMicros >= interval.inMicroseconds) {
      _lastTickMicros = nowMicros;
      return true;
    }
    return false;
  }

  void reset() {
    _lastTickMicros = 0;
  }
}
