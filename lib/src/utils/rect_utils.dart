import 'package:flutter/widgets.dart';

class RectUtils {
  const RectUtils._();

  static Rect? getGlobalRect(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }
    if (!renderObject.attached || !renderObject.hasSize) {
      return null;
    }

    final offset = renderObject.localToGlobal(Offset.zero);
    if (offset.dx.isNaN || offset.dy.isNaN) {
      return null;
    }

    return offset & renderObject.size;
  }
}
