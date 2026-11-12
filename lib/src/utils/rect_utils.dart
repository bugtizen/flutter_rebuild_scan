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

/// Caches shared render ancestry only for one visual refresh.
class RectMeasurementPass {
  final Map<RenderObject, Matrix4> _transforms = {};
  final Map<RenderObject, Rect?> _clips = {};
  final Map<RenderObject, bool> _visible = {};

  Matrix4 _transform(RenderObject node) {
    return _transforms.putIfAbsent(node, () {
      final parent = node.parent;
      if (parent == null || parent.parent == null) return Matrix4.identity();
      final result = _transform(parent).clone();
      parent.applyPaintTransform(node, result);
      return result;
    });
  }

  bool _resolve(RenderObject node) {
    if (_visible.containsKey(node)) return _visible[node]!;
    final parent = node.parent;
    if (parent == null) return _visible[node] = true;
    if (!_resolve(parent) || !parent.paintsChild(node)) {
      return _visible[node] = false;
    }
    var clip = _clips[parent];
    final local = parent.describeApproximatePaintClip(node);
    if (local != null) {
      final global = MatrixUtils.transformRect(_transform(parent), local);
      clip = clip == null ? global : clip.intersect(global);
    }
    _clips[node] = clip;
    return _visible[node] = true;
  }

  Rect? measure(Element element) {
    try {
      if (!element.mounted) return null;
      final render = element.findRenderObject();
      if (render is! RenderBox ||
          !render.attached ||
          !render.hasSize ||
          !_resolve(render)) {
        return null;
      }
      var rect = MatrixUtils.transformRect(
        _transform(render),
        Offset.zero & render.size,
      );
      final clip = _clips[render];
      if (clip != null) rect = rect.intersect(clip);
      return rect.isFinite && !rect.isEmpty ? rect : null;
    } catch (_) {
      return null;
    }
  }
}
