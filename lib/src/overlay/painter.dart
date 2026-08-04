import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';

class RebuildScanHighlightPainter extends CustomPainter {
  RebuildScanHighlightPainter({
    required this.snapshot,
    required this.nowMicros,
  });

  static const int _flashMaxAgeMicros = 400000;
  static const int _nonFlashLingerMicros = 900000;

  final RebuildScanSnapshot snapshot;
  final int nowMicros;

  @override
  void paint(Canvas canvas, Size size) {
    if (!snapshot.enabled) {
      return;
    }

    final mode = snapshot.config.highlightMode;
    final maxRecent = snapshot.topEntries.isEmpty
        ? 1
        : snapshot.topEntries.first.recentCount.clamp(1, 1000000);

    if (mode == HighlightMode.flash) {
      for (final entry in snapshot.entriesById.values) {
        if (entry.rect == null) {
          continue;
        }
        if (entry.recentCount < snapshot.config.minRebuildsToShow) {
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

        final rect = entry.rect!;
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

    for (final entry in snapshot.entriesById.values) {
      if (entry.rect == null) {
        continue;
      }
      if (entry.recentCount < snapshot.config.minRebuildsToShow) {
        continue;
      }
      final ageMicros = nowMicros - entry.lastMicros;
      if (ageMicros < 0 || ageMicros > _nonFlashLingerMicros) {
        continue;
      }

      final rect = entry.rect!;
      if (mode == HighlightMode.heatmap) {
        final intensity = (entry.recentCount / maxRecent).clamp(0.0, 1.0);
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
    final count = switch (snapshot.config.badgeCountMode) {
      RebuildBadgeCountMode.frame => entry.frameCount,
      RebuildBadgeCountMode.recent => entry.recentCount,
      RebuildBadgeCountMode.total => entry.totalCount,
    };
    return 'x$count';
  }

  void _paintOutline(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, paint);
  }

  void _paintFlash(Canvas canvas, Rect rect, double flashStrength) {
    final stroke = Paint()
      ..color = const Color(
        0xFFFFD54F,
      ).withValues(alpha: 0.2 + (0.8 * flashStrength))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fill = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.08 * flashStrength)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  void _paintHeatmap(Canvas canvas, Rect rect, double intensity) {
    final fill = Paint()
      ..color = Color.lerp(
        const Color(0xFFFFFF8D),
        const Color(0xFFD50000),
        intensity,
      )!.withValues(alpha: 0.01 + (0.05 * intensity))
      ..style = PaintingStyle.fill;

    final outline = Paint()
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
    const horizontalPadding = 6.0;
    const verticalPadding = 3.0;
    final badgeAlpha = (0.45 + (0.5 * flashStrength)).clamp(0.0, 1.0);
    final textAlpha = (0.65 + (0.35 * flashStrength)).clamp(0.0, 1.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: textAlpha),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

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

    final badgePaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: badgeAlpha)
      ..style = PaintingStyle.fill;

    canvas.drawRect(badgeRect, badgePaint);
    textPainter.paint(
      canvas,
      Offset(left + horizontalPadding, top + verticalPadding),
    );
  }

  @override
  bool shouldRepaint(covariant RebuildScanHighlightPainter oldDelegate) {
    return oldDelegate.snapshot.frameNumber != snapshot.frameNumber ||
        oldDelegate.snapshot.config != snapshot.config ||
        oldDelegate.snapshot.totalRebuilds != snapshot.totalRebuilds;
  }
}
