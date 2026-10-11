import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paints a dark overlay with a transparent rectangular cutout
class ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 0.7 keeps white text readable over bright scenes.
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.70);

    // Cutout rect — horizontally padded, vertically centered-upper
    final rectW = size.width - 48;
    final rectH = size.height * 0.35;
    final left = 24.0;
    final top = size.height * 0.28;
    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, rectW, rectH),
      const Radius.circular(20),
    );

    // Full screen path minus cutout
    final path = ui.Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutout);
    path.fillType = ui.PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints corner brackets around the scan area
class CornersPainter extends CustomPainter {
  final Rect rect;
  CornersPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 12.0;
    final l = rect.left;
    final t = rect.top;
    final ri = rect.right;
    final b = rect.bottom;

    // Top-left
    canvas.drawPath(
      ui.Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t + r)
        ..quadraticBezierTo(l, t, l + r, t)
        ..lineTo(l + len, t),
      paint,
    );
    // Top-right
    canvas.drawPath(
      ui.Path()
        ..moveTo(ri - len, t)
        ..lineTo(ri - r, t)
        ..quadraticBezierTo(ri, t, ri, t + r)
        ..lineTo(ri, t + len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      ui.Path()
        ..moveTo(l, b - len)
        ..lineTo(l, b - r)
        ..quadraticBezierTo(l, b, l + r, b)
        ..lineTo(l + len, b),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      ui.Path()
        ..moveTo(ri - len, b)
        ..lineTo(ri - r, b)
        ..quadraticBezierTo(ri, b, ri, b - r)
        ..lineTo(ri, b - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CornersPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
