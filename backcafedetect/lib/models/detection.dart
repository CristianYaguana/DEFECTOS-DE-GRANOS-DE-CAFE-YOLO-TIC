import 'package:flutter/material.dart';

class Detection {
  final String label;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final List<Offset> mask;

  const Detection({
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.mask,
  });

  static const List<String> classNames = [
    'agrio_parcial',
    'broca_leve_severa',
    'cereza_seca',
    'concha',
    'cortado',
    'grano_negro',
    'negro_parcial',
    'normal',
    'por_hongo',
  ];

  bool get hasValidBox {
    return x2 > x1 && y2 > y1;
  }

  bool get hasValidMask {
    return mask.length >= 3;
  }

  bool get isBoxNormalized {
    return x1 >= 0 &&
        y1 >= 0 &&
        x2 <= 1 &&
        y2 <= 1 &&
        x2 > x1 &&
        y2 > y1;
  }

  bool get isMaskNormalized {
    if (mask.isEmpty) return false;

    return mask.every(
          (point) =>
      point.dx >= 0 &&
          point.dx <= 1 &&
          point.dy >= 0 &&
          point.dy <= 1,
    );
  }

  String get displayLabel {
    return label
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    })
        .join(' ');
  }

  factory Detection.fromJson(Map<String, dynamic> json) {
    final label = _parseLabel(json);

    final confidence = _toDouble(
      json['confidence'] ??
          json['conf'] ??
          json['score'] ??
          json['probability'] ??
          0.0,
    );

    final bbox = _parseBbox(
      json['bbox'] ??
          json['box'] ??
          json['xyxy'] ??
          json['bounds'] ??
          json,
    );

    final mask = _parseMask(
      json['mask'] ??
          json['polygon'] ??
          json['segmentation'] ??
          json['segments'] ??
          json['points'] ??
          json['contour'] ??
          json['mask_points'],
    );

    return Detection(
      label: label,
      confidence: confidence,
      x1: bbox[0],
      y1: bbox[1],
      x2: bbox[2],
      y2: bbox[3],
      mask: mask,
    );
  }

  static List<Detection> listFromResponse(Map<String, dynamic> response) {
    final rawDetections = response['detections'] ??
        response['results'] ??
        response['data'] ??
        response['predictions'] ??
        [];

    if (rawDetections is! List) return [];

    return rawDetections
        .whereType<Map>()
        .map((item) => Detection.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static int totalFromResponse(Map<String, dynamic> response) {
    final rawTotal = response['total'];

    if (rawTotal is num) {
      return rawTotal.toInt();
    }

    return listFromResponse(response).length;
  }

  static String predictedClassFromResponse(Map<String, dynamic> response) {
    final rawClass = response['predicted_class'] ??
        response['predictedClass'] ??
        response['main_class'] ??
        response['mainClass'];

    if (rawClass == null) return '';

    return _normalizeLabel(rawClass.toString());
  }

  static String _parseLabel(Map<String, dynamic> json) {
    final dynamic rawLabel = json['class'] ??
        json['label'] ??
        json['name'] ??
        json['class_name'] ??
        json['defect'] ??
        json['cls_name'];

    if (rawLabel != null) {
      if (rawLabel is num) {
        final index = rawLabel.toInt();

        if (index >= 0 && index < classNames.length) {
          return classNames[index];
        }
      }

      final text = rawLabel.toString().trim();

      final index = int.tryParse(text);

      if (index != null && index >= 0 && index < classNames.length) {
        return classNames[index];
      }

      if (text.isNotEmpty) {
        return _normalizeLabel(text);
      }
    }

    final dynamic rawClassId = json['class_id'] ??
        json['cls'] ??
        json['category_id'] ??
        json['id'];

    if (rawClassId != null) {
      if (rawClassId is num) {
        final index = rawClassId.toInt();

        if (index >= 0 && index < classNames.length) {
          return classNames[index];
        }
      }

      final index = int.tryParse(rawClassId.toString());

      if (index != null && index >= 0 && index < classNames.length) {
        return classNames[index];
      }
    }

    return 'desconocido';
  }

  static String _normalizeLabel(String value) {
    final text = value.trim().toLowerCase();

    for (final className in classNames) {
      if (text == className.toLowerCase()) {
        return className;
      }
    }

    return text;
  }

  static List<double> _parseBbox(dynamic value) {
    if (value is Map) {
      final x1 = _toDouble(value['x1'] ?? value['xmin'] ?? value['left']);
      final y1 = _toDouble(value['y1'] ?? value['ymin'] ?? value['top']);
      final x2 = _toDouble(value['x2'] ?? value['xmax'] ?? value['right']);
      final y2 = _toDouble(value['y2'] ?? value['ymax'] ?? value['bottom']);

      if (x2 > x1 && y2 > y1) {
        return [x1, y1, x2, y2];
      }

      final x = _toDouble(value['x']);
      final y = _toDouble(value['y']);
      final width = _toDouble(value['width'] ?? value['w']);
      final height = _toDouble(value['height'] ?? value['h']);

      if (width > 0 && height > 0) {
        return [x, y, x + width, y + height];
      }
    }

    if (value is List && value.length >= 4) {
      return [
        _toDouble(value[0]),
        _toDouble(value[1]),
        _toDouble(value[2]),
        _toDouble(value[3]),
      ];
    }

    return [0, 0, 0, 0];
  }

  static List<Offset> _parseMask(dynamic value) {
    if (value == null) return [];

    if (value is Map) {
      if (value.containsKey('x') && value.containsKey('y')) {
        return [
          Offset(
            _toDouble(value['x']),
            _toDouble(value['y']),
          ),
        ];
      }

      final inner = value['points'] ??
          value['mask'] ??
          value['polygon'] ??
          value['segmentation'];

      if (inner != null) {
        return _parseMask(inner);
      }

      return [];
    }

    if (value is! List || value.isEmpty) return [];

    if (value.first is Map) {
      final points = <Offset>[];

      for (final item in value) {
        if (item is Map && item.containsKey('x') && item.containsKey('y')) {
          points.add(
            Offset(
              _toDouble(item['x']),
              _toDouble(item['y']),
            ),
          );
        }
      }

      return points;
    }

    if (value.first is num) {
      final points = <Offset>[];

      for (int i = 0; i + 1 < value.length; i += 2) {
        points.add(
          Offset(
            _toDouble(value[i]),
            _toDouble(value[i + 1]),
          ),
        );
      }

      return points;
    }

    if (value.first is List) {
      final first = value.first;

      if (first is List && first.length >= 2 && first.first is num) {
        final points = <Offset>[];

        for (final point in value) {
          if (point is List && point.length >= 2) {
            points.add(
              Offset(
                _toDouble(point[0]),
                _toDouble(point[1]),
              ),
            );
          }
        }

        return points;
      }

      for (final item in value) {
        final parsed = _parseMask(item);

        if (parsed.length >= 3) {
          return parsed;
        }
      }
    }

    return [];
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static Color colorForLabel(String label) {
    final cleanLabel = _normalizeLabel(label);

    switch (cleanLabel) {
      case 'agrio_parcial':
        return const Color(0xFFFFB300);
      case 'broca_leve_severa':
        return const Color(0xFF795548);
      case 'cereza_seca':
        return const Color(0xFFE65100);
      case 'concha':
        return const Color(0xFF8E24AA);
      case 'cortado':
        return const Color(0xFFE53935);
      case 'grano_negro':
        return const Color(0xFF212121);
      case 'negro_parcial':
        return const Color(0xFF546E7A);
      case 'normal':
        return const Color(0xFF43A047);
      case 'por_hongo':
        return const Color(0xFF00897B);
      default:
        return const Color(0xFF1E88E5);
    }
  }
}