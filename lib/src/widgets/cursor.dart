import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../rendering/editor.dart';

// The time it takes for the cursor to fade from fully opaque to fully
// transparent and vice versa. A full cursor blink, from transparent to opaque
// to transparent, is twice this duration.
const Duration _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);

// The time the cursor is static in opacity before animating to become
// transparent.
const Duration _kCursorBlinkWaitForStart = Duration(milliseconds: 150);

/// Style properties of editing cursor.
class CursorStyle {
  /// The color to use when painting the cursor.
  ///
  /// Cannot be null.
  final Color color;

  /// The color to use when painting the background cursor aligned with the text
  /// while rendering the floating cursor.
  ///
  /// Cannot be null. By default it is the disabled grey color from
  /// CupertinoColors.
  final Color backgroundColor;

  /// How thick the cursor will be.
  ///
  /// Defaults to 1.0
  ///
  /// The cursor will draw under the text. The cursor width will extend
  /// to the right of the boundary between characters for left-to-right text
  /// and to the left for right-to-left text. This corresponds to extending
  /// downstream relative to the selected position. Negative values may be used
  /// to reverse this behavior.
  final double width;

  /// How tall the cursor will be.
  ///
  /// By default, the cursor height is set to the preferred line height of the
  /// text.
  final double? height;

  /// How rounded the corners of the cursor should be.
  ///
  /// By default, the cursor has no radius.
  final Radius? radius;

  /// The offset that is used, in pixels, when painting the cursor on screen.
  ///
  /// By default, the cursor position should be set to an offset of
  /// (-[cursorWidth] * 0.5, 0.0) on iOS platforms and (0, 0) on Android
  /// platforms. The origin from where the offset is applied to is the arbitrary
  /// location where the cursor ends up being rendered from by default.
  final Offset? offset;

  /// Whether the cursor will animate from fully transparent to fully opaque
  /// during each cursor blink.
  ///
  /// By default, the cursor opacity will animate on iOS platforms and will not
  /// animate on Android platforms.
  final bool opacityAnimates;

  /// If the cursor should be painted on top of the text or underneath it.
  ///
  /// By default, the cursor should be painted on top for iOS platforms and
  /// underneath for Android platforms.
  final bool paintAboveText;

  const CursorStyle({
    required this.color,
    required this.backgroundColor,
    this.width = 1.0,
    this.height,
    this.radius,
    this.offset,
    this.opacityAnimates = false,
    this.paintAboveText = false,
  });

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! CursorStyle) return false;
    return other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.width == width &&
        other.height == height &&
        other.radius == radius &&
        other.offset == offset &&
        other.opacityAnimates == opacityAnimates &&
        other.paintAboveText == paintAboveText;
  }

  @override
  int get hashCode => Object.hash(color, backgroundColor, width, height, radius,
      offset, opacityAnimates, paintAboveText);
}

/// Controls cursor of an editable widget.
///
/// This class is a [ChangeNotifier] and allows to listen for updates on the
/// cursor [style].
class CursorController extends ChangeNotifier {
  CursorController({
    required ValueNotifier<bool> showCursor,
    required CursorStyle style,
    required TickerProvider tickerProvider,
  })  : showCursor = showCursor,
        _style = style,
        _cursorBlink = ValueNotifier(false),
        _cursorColor = ValueNotifier(style.color) {
    _cursorBlinkOpacityController =
        AnimationController(vsync: tickerProvider, duration: _fadeDuration);
    _cursorBlinkOpacityController.addListener(_onCursorColorTick);
  }

  // This value is an eyeball estimation of the time it takes for the iOS cursor
  // to ease in and out.
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  final ValueNotifier<bool> showCursor;

  Timer? _cursorTimer;
  bool _targetCursorVisibility = false;
  late AnimationController _cursorBlinkOpacityController;

  ValueNotifier<bool> get cursorBlink => _cursorBlink;
  final ValueNotifier<bool> _cursorBlink;

  ValueNotifier<Color> get cursorColor => _cursorColor;
  final ValueNotifier<Color> _cursorColor;

  CursorStyle get style => _style;
  CursorStyle _style;

  set style(CursorStyle value) {
    if (_style == value) return;
    _style = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _cursorBlinkOpacityController.removeListener(_onCursorColorTick);
    stopCursorTimer();
    _cursorBlinkOpacityController.dispose();
    assert(_cursorTimer == null);
    super.dispose();
  }

  void _cursorTick(Timer timer) {
    _targetCursorVisibility = !_targetCursorVisibility;
    final targetOpacity = _targetCursorVisibility ? 1.0 : 0.0;
    if (style.opacityAnimates) {
      // If we want to show the cursor, we will animate the opacity to the value
      // of 1.0, and likewise if we want to make it disappear, to 0.0. An easing
      // curve is used for the animation to mimic the aesthetics of the native
      // iOS cursor.
      //
      // These values and curves have been obtained through eyeballing, so are
      // likely not exactly the same as the values for native iOS.
      _cursorBlinkOpacityController.animateTo(targetOpacity,
          curve: Curves.easeOut);
    } else {
      _cursorBlinkOpacityController.value = targetOpacity;
    }
  }

  void _cursorWaitForStart(Timer timer) {
    assert(_kCursorBlinkHalfPeriod > _fadeDuration);
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
  }

  void startCursorTimer() {
    _targetCursorVisibility = true;
    _cursorBlinkOpacityController.value = 1.0;

    if (style.opacityAnimates) {
      _cursorTimer =
          Timer.periodic(_kCursorBlinkWaitForStart, _cursorWaitForStart);
    } else {
      _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
    }
  }

  void stopCursorTimer({bool resetCharTicks = true}) {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _targetCursorVisibility = false;
    _cursorBlinkOpacityController.value = 0.0;

    if (style.opacityAnimates) {
      _cursorBlinkOpacityController.stop();
      _cursorBlinkOpacityController.value = 0.0;
    }
  }

  void startOrStopCursorTimerIfNeeded(bool hasFocus, TextSelection selection) {
    if (showCursor.value &&
        _cursorTimer == null &&
        hasFocus &&
        selection.isCollapsed) {
      startCursorTimer();
    } else if (_cursorTimer != null && (!hasFocus || !selection.isCollapsed)) {
      stopCursorTimer();
    }
  }

  void _onCursorColorTick() {
    _cursorColor.value =
        _style.color.withOpacity(_cursorBlinkOpacityController.value);
    cursorBlink.value =
        showCursor.value && _cursorBlinkOpacityController.value > 0;
  }
}

/// Handles floating cursor gestures (e.g. long-pressing the space bar on the
/// iOS keyboard to use it as a trackpad).
///
/// Ported from [EditableTextState.updateFloatingCursor] and
/// [RenderEditable.calculateBoundedFloatingCursorOffset]. Unlike Flutter's
/// implementation, a separate floating cursor is not painted. Instead the
/// regular caret is moved as the gesture progresses.
class FloatingCursorController {
  // The center of the caret on FloatingCursorDragState.start, in
  // [RenderEditor]'s local coordinates.
  Offset? _startCaretCenter;

  // The offset of the floating cursor as reported on
  // FloatingCursorDragState.start. Points reported afterwards are relative to
  // this origin.
  Offset? _pointOffsetOrigin;

  // The relative origin in relation to the distance the user has theoretically
  // dragged the floating cursor outside of the editor. This value is used to
  // account for the difference between the bounded and the raw offset value.
  Offset _relativeOrigin = Offset.zero;
  Offset? _previousOffset;
  bool _resetOriginOnLeft = false;
  bool _resetOriginOnRight = false;
  bool _resetOriginOnTop = false;
  bool _resetOriginOnBottom = false;

  /// Processes a floating cursor [point] reported by the platform.
  ///
  /// Returns the text position the caret should be moved to, or `null` if the
  /// caret should stay where it is.
  TextPosition? updateFloatingCursor(
      RawFloatingCursorPoint point, RenderEditor renderEditor) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
        _reset();
        _pointOffsetOrigin = point.offset;
        final selection = renderEditor.selection;
        if (!selection.isValid) {
          _reset();
          return null;
        }
        final caretBottom = renderEditor
            .getEndpointsForSelection(TextSelection.collapsed(
              offset: selection.baseOffset,
              affinity: selection.affinity,
            ))
            .first
            .point;
        final lineHeight = renderEditor
            .preferredLineHeight(TextPosition(offset: selection.baseOffset));
        _startCaretCenter = caretBottom - Offset(0, lineHeight / 2);
        return null;
      case FloatingCursorDragState.Update:
        final startCaretCenter = _startCaretCenter;
        final pointOffsetOrigin = _pointOffsetOrigin;
        final pointOffset = point.offset;
        if (startCaretCenter == null ||
            pointOffsetOrigin == null ||
            pointOffset == null) {
          return null;
        }
        final rawCursorOffset =
            startCaretCenter + pointOffset - pointOffsetOrigin;
        final boundedOffset =
            _calculateBoundedOffset(rawCursorOffset, renderEditor);
        return renderEditor
            .getPositionForOffset(renderEditor.localToGlobal(boundedOffset));
      case FloatingCursorDragState.End:
        _reset();
        return null;
    }
  }

  void _reset() {
    _startCaretCenter = null;
    _pointOffsetOrigin = null;
    _relativeOrigin = Offset.zero;
    _previousOffset = null;
    _resetOriginOnLeft = false;
    _resetOriginOnRight = false;
    _resetOriginOnTop = false;
    _resetOriginOnBottom = false;
  }

  Offset _calculateBoundedOffset(
      Offset rawCursorOffset, RenderEditor renderEditor) {
    final bounds = Offset.zero & renderEditor.size;
    // Keep the lookup point strictly inside the editor.
    final boundingRect = Rect.fromLTRB(
        bounds.left,
        bounds.top,
        math.max(bounds.left, bounds.right - 1),
        math.max(bounds.top, bounds.bottom - 1));

    var deltaPosition = Offset.zero;
    if (_previousOffset != null) {
      deltaPosition = rawCursorOffset - _previousOffset!;
    }

    // If the raw cursor offset has gone off an edge, we want to reset the
    // relative origin of the dragging when the user drags back into the editor.
    if (_resetOriginOnLeft && deltaPosition.dx > 0) {
      _relativeOrigin =
          Offset(rawCursorOffset.dx - boundingRect.left, _relativeOrigin.dy);
      _resetOriginOnLeft = false;
    } else if (_resetOriginOnRight && deltaPosition.dx < 0) {
      _relativeOrigin =
          Offset(rawCursorOffset.dx - boundingRect.right, _relativeOrigin.dy);
      _resetOriginOnRight = false;
    }
    if (_resetOriginOnTop && deltaPosition.dy > 0) {
      _relativeOrigin =
          Offset(_relativeOrigin.dx, rawCursorOffset.dy - boundingRect.top);
      _resetOriginOnTop = false;
    } else if (_resetOriginOnBottom && deltaPosition.dy < 0) {
      _relativeOrigin =
          Offset(_relativeOrigin.dx, rawCursorOffset.dy - boundingRect.bottom);
      _resetOriginOnBottom = false;
    }

    final currentX = rawCursorOffset.dx - _relativeOrigin.dx;
    final currentY = rawCursorOffset.dy - _relativeOrigin.dy;
    final adjustedOffset =
        _clampOffset(Offset(currentX, currentY), boundingRect);

    if (currentX < boundingRect.left && deltaPosition.dx < 0) {
      _resetOriginOnLeft = true;
    } else if (currentX > boundingRect.right && deltaPosition.dx > 0) {
      _resetOriginOnRight = true;
    }
    if (currentY < boundingRect.top && deltaPosition.dy < 0) {
      _resetOriginOnTop = true;
    } else if (currentY > boundingRect.bottom && deltaPosition.dy > 0) {
      _resetOriginOnBottom = true;
    }

    _previousOffset = rawCursorOffset;

    return adjustedOffset;
  }

  static Offset _clampOffset(Offset offset, Rect bounds) {
    return Offset(
      clampDouble(offset.dx, bounds.left, bounds.right),
      clampDouble(offset.dy, bounds.top, bounds.bottom),
    );
  }
}
