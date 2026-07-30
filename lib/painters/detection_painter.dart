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
      if (!detection.hasValidBox) continue;

      final color = Detection.colorForLabel(detection.label);

      // Calcular coordenadas escaladas
      double left = detection.x1;
      double top = detection.y1;
      double right = detection.x2;
      double bottom = detection.y2;

      if (detection.isBoxNormalized) {
        left *= imageSize.width;
        top *= imageSize.height;
        right *= imageSize.width;
        bottom *= imageSize.height;
      }

      final rect = Rect.fromLTRB(
        destinationRect.left + left * scaleX,
        destinationRect.top + top * scaleY,
        destinationRect.left + right * scaleX,
        destinationRect.top + bottom * scaleY,
      );

      // Dibujar SOLO el borde de la caja, sin relleno y sin etiqueta
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.image != image;
  }
}