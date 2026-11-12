// ignore_for_file: public_member_api_docs
/// Overlay-only hysteresis. Rebuild events are never sampled.
class VisualRefresh {
  int _tier = 0;
  int? _healthySince;
  int get intervalMicros => const [16667, 33334, 66667][_tier];
  void record(int elapsed, int now) {
    if (elapsed > 1000) {
      if (_tier < 2) _tier++;
      _healthySince = null;
    } else if (elapsed < 500) {
      _healthySince ??= now;
      if (now - _healthySince! >= 1000000) {
        if (_tier > 0) _tier--;
        _healthySince = now;
      }
    } else {
      _healthySince = null;
    }
  }
}
