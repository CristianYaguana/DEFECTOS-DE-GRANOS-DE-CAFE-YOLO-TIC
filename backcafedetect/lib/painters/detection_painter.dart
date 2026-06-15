import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/detection.dart';

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final ui.Image image;

  DetectionPainter({
    required this.detections,
    required this.image,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final fittedSizes = applyBoxFit(
      BoxFit.contain,
      imageSize,
      size,
    );

    final destinationRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );

    final scaleX = destinationRect.width / imageSize.width;
    final scaleY = destinationRect.height / imageSize.height;

    for (final detection in detections) {
      if (!detection.hasValidMask) continue;

      final color = Detection.colorForLabel(detection.label);

      _drawSegmentation(
        canvas: canvas,
        detection: detection,
        color: color,
        imageSize: imageSize,
        destinationRect: destinationRect,
        scaleX: scaleX,
        scaleY: scaleY,
      );
    }
  }

  void _drawSegmentation({
    required Canvas canvas,
    required Detection detection,
    required Color color,
    required Size imageSize,
    required Rect destinationRect,
    required double scaleX,
    required double scaleY,
  }) {
    final mappedPoints = <Offset>[];

    for (final point in detection.mask) {
      final px = detection.isMaskNormalized
          ? point.dx * imageSize.width
          : point.dx;

      final py = detection.isMaskNormalized
          ? point.dy * imageSize.height
          : point.dy;

      mappedPoints.add(
        Offset(
          destinationRect.left + px * scaleX,
          destinationRect.top + py * scaleY,
        ),
      );
    }

    if (mappedPoints.length < 3) return;

    final smoothPath = _buildSmoothClosedPath(mappedPoints);

    final fillPaint = Paint()
      ..color = color.withOpacity(0.28)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(smoothPath, fillPaint);
    canvas.drawPath(smoothPath, borderPaint);
  }

  Path _buildSmoothClosedPath(List<Offset> points) {
    final path = Path();

    if (points.length < 3) {
      return path;
    }

    final cleaned = _reduceVeryClosePoints(points);

    if (cleaned.length < 3) {
      return path;
    }

    path.moveTo(cleaned.first.dx, cleaned.first.dy);

    for (int i = 0; i < cleaned.length; i++) {
      final current = cleaned[i];
      final next = cleaned[(i + 1) % cleaned.length];

      final midPoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );

      path.quadraticBezierTo(
        current.dx,
        current.dy,
        midPoint.dx,
        midPoint.dy,
      );
    }

    path.close();
    return path;
  }

  List<Offset> _reduceVeryClosePoints(List<Offset> points) {
    if (points.length <= 3) return points;

    final filtered = <Offset>[];
    filtered.add(points.first);

    for (int i = 1; i < points.length; i++) {
      final last = filtered.last;
      final current = points[i];

      final dx = current.dx - last.dx;
      final dy = current.dy - last.dy;
      final distanceSquared = dx * dx + dy * dy;

      if (distanceSquared > 4.0) {
        filtered.add(current);
      }
    }

    if (filtered.length >= 3) {
      final first = filtered.first;
      final last = filtered.last;
      final dx = first.dx - last.dx;
      final dy = first.dy - last.dy;
      final distanceSquared = dx * dx + dy * dy;

      if (distanceSquared < 4.0 && filtered.length > 3) {
        filtered.removeLast();
      }
    }

    return filtered;
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.image != image;
  }
}