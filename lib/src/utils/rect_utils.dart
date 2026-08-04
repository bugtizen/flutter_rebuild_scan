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

    final Offset offset;
    try {
      offset = renderObject.localToGlobal(Offset.zero);
    } catch (_) {
      return null;
    }

    final size = renderObject.size;
    if (!_isFiniteOffset(offset) || !_isFiniteSize(size)) {
      return null;
    }

    return offset & size;
  }

  static bool _isFiniteOffset(Offset offset) {
    return offset.dx.isFinite && offset.dy.isFinite;
  }

  static bool _isFiniteSize(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        !size.width.isNaN &&
        !size.height.isNaN;
  }
}
