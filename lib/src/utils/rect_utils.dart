// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart';

class RectUtils {
  const RectUtils._();

  static Rect? getGlobalRect(Element element) {
    if (!element.mounted) {
      return null;
    }

    final RenderObject? renderObject;
    try {
      renderObject = element.findRenderObject();
    } catch (_) {
      return null;
    }

    if (renderObject is! RenderBox) {
      return null;
    }
    if (!renderObject.attached || !renderObject.hasSize) {
      return null;
    }

    try {
      var rect = MatrixUtils.transformRect(
        renderObject.getTransformTo(null),
        Offset.zero & renderObject.size,
      );
      RenderObject child = renderObject;
      while (child.parent != null) {
        final parent = child.parent!;
        if (!parent.paintsChild(child)) return null;
        final clip = parent.describeApproximatePaintClip(child);
        if (clip != null) {
          rect = rect.intersect(
            MatrixUtils.transformRect(parent.getTransformTo(null), clip),
          );
        }
        child = parent;
      }
      return rect.isFinite && !rect.isEmpty ? rect : null;
    } catch (_) {
      return null;
    }
  }
}
