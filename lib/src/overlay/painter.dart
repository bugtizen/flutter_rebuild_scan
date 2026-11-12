// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import '../controller.dart';
import '../config.dart';
import '../models.dart';

class RebuildScanHighlightPainter extends CustomPainter {
  RebuildScanHighlightPainter({required this.controller, this.origin})
    : super(repaint: controller.repaint);

  static const int _flashMaxAgeMicros = 400000;

  final RebuildScanController controller;
  final Offset Function()? origin;
  final Map<String, TextPainter> _badges = {};
  final Paint _fill = Paint();
  final Paint _stroke = Paint();
  final Paint _badge = Paint();
  final Paint _badgeBorder = Paint();
  void disposeResources() {
    for (final text in _badges.values) {
      text.dispose();
    }
    _badges.clear();
  }

  RebuildScanSnapshot get snapshot => controller.visualSnapshot();
  late RebuildScanConfig _config;
  List<RebuildScanEntrySnapshot> _entries = const [];
  int nowMicros = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final watch = Stopwatch()..start();
    try {
      _paint(canvas, size);
    } finally {
      controller.recordVisualCost(watch.elapsedMicroseconds);
    }
  }

  void _paint(Canvas canvas, Size size) {
    _entries = controller.prepareVisualEntries();
    _config = controller.config;
    nowMicros = controller.timestampMicros;
    canvas.clipRect(Offset.zero & size);
    if (!controller.isEnabled) {
      return;
    }

    final overlayOrigin = origin?.call() ?? Offset.zero;
    final mode = _config.highlightMode;

    if (mode == HighlightMode.flash) {
      for (final entry in _entries) {
        if (entry.rect == null) {
          continue;
        }
        if (entry.recentCount < _config.minRebuildsToShow) {
          continue;
        }

        final ageMicros = nowMicros - entry.lastMicros;
        if (ageMicros < 0 || ageMicros > _flashMaxAgeMicros) {
          continue;
        }

        final flashStrength = (1.0 - ageMicros / _flashMaxAgeMicros).clamp(
          0.0,
          1.0,
        );
        if (flashStrength <= 0) {
          continue;
        }

        final rect = entry.rect!.shift(-overlayOrigin);
        _paintFlash(canvas, rect, flashStrength);
        _paintCounterBadge(
          canvas,
          rect,
          label: _badgeLabel(entry),
          viewport: size,
          flashStrength: flashStrength,
        );
      }
      return;
    }

    for (final entry in _entries) {
      if (entry.rect == null) {
        continue;
      }
      if (entry.recentCount < _config.minRebuildsToShow) {
        continue;
      }
      final ageMicros = nowMicros - entry.lastMicros;
      if (ageMicros < 0 || ageMicros > _config.sampleWindow.inMicroseconds) {
        continue;
      }

      final rect = entry.rect!.shift(-overlayOrigin);
      if (mode == HighlightMode.heatmap) {
        final intensity =
            (entry.recentCount /
                    _config.sampleWindow.inMicroseconds *
                    1000000 /
                    _config.heatmapMaxRebuildsPerSecond)
                .clamp(0.0, 1.0);
        _paintHeatmap(canvas, rect, intensity);
      } else {
        _paintOutline(canvas, rect);
      }

      _paintCounterBadge(
        canvas,
        rect,
        label: _badgeLabel(entry),
        viewport: size,
      );
    }
  }

  String _badgeLabel(RebuildScanEntrySnapshot entry) {
    final count = switch (_config.badgeCountMode) {
      RebuildBadgeCountMode.frame => entry.frameCount,
      RebuildBadgeCountMode.recent => entry.recentCount,
      RebuildBadgeCountMode.total => entry.totalCount,
    };
    return 'x$count';
  }

  void _paintOutline(Canvas canvas, Rect rect) {
    final paint = _stroke
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, paint);
  }

  void _paintFlash(Canvas canvas, Rect rect, double flashStrength) {
    final stroke = _stroke
      ..color = const Color(
        0xFFFFD54F,
      ).withValues(alpha: 0.2 + (0.8 * flashStrength))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fill = _fill
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.08 * flashStrength)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  void _paintHeatmap(Canvas canvas, Rect rect, double intensity) {
    final fill = _fill
      ..color = Color.lerp(
        const Color(0xFFFFFF8D),
        const Color(0xFFD50000),
        intensity,
      )!.withValues(alpha: 0.04 + (0.16 * intensity))
      ..style = PaintingStyle.fill;

    final outline = _stroke
      ..color = const Color(
        0xFFFF6D00,
      ).withValues(alpha: 0.5 + (0.5 * intensity))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, outline);
  }

  void _paintCounterBadge(
    Canvas canvas,
    Rect rect, {
    required String label,
    required Size viewport,
    double flashStrength = 1.0,
  }) {
    const horizontalPadding = 7.0;
    const verticalPadding = 4.0;
    final badgeAlpha = (0.8 + (0.2 * flashStrength)).clamp(0.0, 1.0);

    if (_badges.length >= 128 && !_badges.containsKey(label)) {
      _badges.remove(_badges.keys.first)!.dispose();
    }
    final textPainter = _badges.putIfAbsent(
      label,
      () => TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.85),
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(),
    );

    final badgeSize = Size(
      textPainter.width + (horizontalPadding * 2),
      textPainter.height + (verticalPadding * 2),
    );

    var left = rect.right - badgeSize.width + 1;
    var top = rect.top - 18;
    if (left + badgeSize.width > viewport.width) {
      left = viewport.width - badgeSize.width;
    }
    if (top + badgeSize.height > viewport.height) {
      top = viewport.height - badgeSize.height;
    }
    if (left < 0) {
      left = 0;
    }
    if (top < 0) {
      top = 0;
    }

    final badgeRect = Rect.fromLTWH(
      left,
      top,
      badgeSize.width,
      badgeSize.height,
    );

    final badgePaint = _badge
      ..color = const Color(0xFFFFD54F).withValues(alpha: badgeAlpha)
      ..style = PaintingStyle.fill;
    final borderPaint = _badgeBorder
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(badgeRect, badgePaint);
    canvas.drawRect(badgeRect, borderPaint);
    textPainter.paint(
      canvas,
      Offset(left + horizontalPadding, top + verticalPadding),
    );
  }

  @override
  bool shouldRepaint(covariant RebuildScanHighlightPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}
