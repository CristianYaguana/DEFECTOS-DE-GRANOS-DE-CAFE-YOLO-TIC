import 'package:flutter/material.dart';

class Detection {
  final String label;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const Detection({
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
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

  bool get isBoxNormalized {
    return x1 >= 0 &&
        y1 >= 0 &&
        x2 <= 1 &&
        y2 <= 1 &&
        x2 > x1 &&
        y2 > y1 &&
        (x2 - x1) <= 1.0 &&
        (y2 - y1) <= 1.0;
  }

  String get displayLabel {
    return label
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;

      return word[0].toUpperCase() +
          word.substring(1);
    })
        .join(' ');
  }

  factory Detection.fromJson(
      Map<String, dynamic> json) {
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

    return Detection(
      label: label,
      confidence: confidence,
      x1: bbox[0],
      y1: bbox[1],
      x2: bbox[2],
      y2: bbox[3],
    );
  }

  static List<Detection> listFromResponse(
      Map<String, dynamic> response) {
    final rawDetections =
        response['detections'] ??
            response['results'] ??
            response['data'] ??
            response['predictions'] ??
            [];

    if (rawDetections is! List) {
      return [];
    }

    return rawDetections
        .whereType<Map>()
        .map(
          (item) => Detection.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  // ============================================================
  // CONTAR GRANOS SIN DUPLICAR
  // ============================================================
  //
  // Varias detecciones pueden pertenecer al mismo grano.
  //
  // Ejemplo:
  //
  //  detección 1 -> cereza_seca
  //  detección 2 -> grano_negro
  //  detección 3 -> por_hongo
  //
  // Si las cajas se parecen o se solapan fuertemente,
  // se consideran UN SOLO GRANO.
  //
  // IMPORTANTE:
  // Esto NO elimina los defectos de las estadísticas.
  // Solamente evita duplicar el número total de granos.
  //

  static int uniqueGrainsCount(
      List<Detection> detections) {
    final validDetections = detections
        .where(
          (detection) =>
      detection.hasValidBox,
    )
        .toList();

    if (validDetections.isEmpty) {
      return 0;
    }

    // Aquí guardaremos una detección representante
    // de cada grano.
    final List<Detection> uniqueGrains = [];

    for (final detection in validDetections) {
      bool belongsToExistingGrain = false;

      for (final existingGrain in uniqueGrains) {
        if (_sameGrain(
          detection,
          existingGrain,
        )) {
          belongsToExistingGrain = true;
          break;
        }
      }

      // Si no pertenece a ningún grano existente,
      // creamos un nuevo grano.
      if (!belongsToExistingGrain) {
        uniqueGrains.add(detection);
      }
    }

    return uniqueGrains.length;
  }

  // ============================================================
  // DETERMINAR SI DOS DETECCIONES SON EL MISMO GRANO
  // ============================================================

  static bool _sameGrain(
      Detection a,
      Detection b,
      ) {
    // Primero verificamos que ambas cajas sean válidas.
    if (!a.hasValidBox ||
        !b.hasValidBox) {
      return false;
    }

    // ----------------------------------------------------------
    // 1. IoU
    // ----------------------------------------------------------
    //
    // IoU = área de intersección / área de unión.
    //
    // Mientras más alto sea el valor, más parecidas son
    // las cajas.
    //
    // 0.00 -> no se parecen
    // 0.50 -> bastante solapamiento
    // 1.00 -> cajas idénticas
    //
    final iou = _calculateIoU(a, b);

    // Para detecciones del mismo grano permitimos un
    // solapamiento moderado.
    if (iou >= 0.35) {
      return true;
    }

    // ----------------------------------------------------------
    // 2. UNA CAJA DENTRO DE LA OTRA
    // ----------------------------------------------------------
    //
    // En algunos casos el modelo puede detectar el mismo grano
    // con una caja grande y otra más pequeña.
    //
    // En ese caso el IoU puede ser menor, aunque realmente
    // se trate del mismo grano.
    //

    final containment =
    _calculateContainment(a, b);

    if (containment >= 0.65) {
      return true;
    }

    // ----------------------------------------------------------
    // 3. CENTRO DE LAS CAJAS
    // ----------------------------------------------------------
    //
    // También comprobamos que los centros estén suficientemente
    // cerca.
    //
    // Esto ayuda cuando las cajas son ligeramente diferentes.
    //

    final centerDistance =
    _centerDistance(a, b);

    final averageDiagonal =
        (_diagonal(a) + _diagonal(b)) / 2;

    if (averageDiagonal > 0) {
      final relativeDistance =
          centerDistance / averageDiagonal;

      // Si los centros están bastante cerca,
      // consideramos que representan el mismo grano.
      if (relativeDistance <= 0.30) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CALCULAR IoU
  // ============================================================

  static double _calculateIoU(
      Detection a,
      Detection b) {
    final intersectionLeft =
    _max(a.x1, b.x1);

    final intersectionTop =
    _max(a.y1, b.y1);

    final intersectionRight =
    _min(a.x2, b.x2);

    final intersectionBottom =
    _min(a.y2, b.y2);

    final intersectionWidth =
        intersectionRight -
            intersectionLeft;

    final intersectionHeight =
        intersectionBottom -
            intersectionTop;

    // No existe intersección.
    if (intersectionWidth <= 0 ||
        intersectionHeight <= 0) {
      return 0.0;
    }

    final intersectionArea =
        intersectionWidth *
            intersectionHeight;

    final areaA =
        (a.x2 - a.x1) *
            (a.y2 - a.y1);

    final areaB =
        (b.x2 - b.x1) *
            (b.y2 - b.y1);

    final unionArea =
        areaA +
            areaB -
            intersectionArea;

    if (unionArea <= 0) {
      return 0.0;
    }

    return intersectionArea /
        unionArea;
  }

  // ============================================================
  // PORCENTAJE DE UNA CAJA QUE ESTÁ DENTRO DE LA OTRA
  // ============================================================

  static double _calculateContainment(
      Detection a,
      Detection b) {
    final intersectionLeft =
    _max(a.x1, b.x1);

    final intersectionTop =
    _max(a.y1, b.y1);

    final intersectionRight =
    _min(a.x2, b.x2);

    final intersectionBottom =
    _min(a.y2, b.y2);

    final intersectionWidth =
        intersectionRight -
            intersectionLeft;

    final intersectionHeight =
        intersectionBottom -
            intersectionTop;

    if (intersectionWidth <= 0 ||
        intersectionHeight <= 0) {
      return 0.0;
    }

    final intersectionArea =
        intersectionWidth *
            intersectionHeight;

    final areaA =
        (a.x2 - a.x1) *
            (a.y2 - a.y1);

    final areaB =
        (b.x2 - b.x1) *
            (b.y2 - b.y1);

    if (areaA <= 0 ||
        areaB <= 0) {
      return 0.0;
    }

    // Calculamos cuánto de la caja pequeña
    // está dentro de la caja grande.
    final smallerArea =
    areaA < areaB
        ? areaA
        : areaB;

    return intersectionArea /
        smallerArea;
  }

  // ============================================================
  // DISTANCIA ENTRE CENTROS
  // ============================================================

  static double _centerDistance(
      Detection a,
      Detection b) {
    final centerAX =
        (a.x1 + a.x2) / 2;

    final centerAY =
        (a.y1 + a.y2) / 2;

    final centerBX =
        (b.x1 + b.x2) / 2;

    final centerBY =
        (b.y1 + b.y2) / 2;

    final dx =
        centerAX - centerBX;

    final dy =
        centerAY - centerBY;

    return _sqrt(
      (dx * dx) +
          (dy * dy),
    );
  }

  // ============================================================
  // DIAGONAL DE LA CAJA
  // ============================================================

  static double _diagonal(
      Detection detection) {
    final width =
        detection.x2 -
            detection.x1;

    final height =
        detection.y2 -
            detection.y1;

    return _sqrt(
      (width * width) +
          (height * height),
    );
  }

  // ============================================================
  // FUNCIONES MATEMÁTICAS
  // ============================================================

  static double _max(
      double a,
      double b) {
    return a > b ? a : b;
  }

  static double _min(
      double a,
      double b) {
    return a < b ? a : b;
  }

  static double _sqrt(
      double value) {
    // Método sencillo para no necesitar otro paquete.
    if (value <= 0) {
      return 0.0;
    }

    double result = value;

    for (int i = 0; i < 10; i++) {
      result =
          0.5 *
              (result +
                  value / result);
    }

    return result;
  }

  // ============================================================
  // TOTAL DE GRANOS
  // ============================================================

  static int totalFromResponse(
      Map<String, dynamic> response) {
    final detections =
    listFromResponse(response);

    return uniqueGrainsCount(
      detections,
    );
  }

  // ============================================================
  // OBTENER CLASE
  // ============================================================

  static String _parseLabel(
      Map<String, dynamic> json) {
    final dynamic rawLabel =
        json['class'] ??
            json['label'] ??
            json['name'] ??
            json['class_name'] ??
            json['defect'] ??
            json['cls_name'];

    if (rawLabel != null) {
      if (rawLabel is num) {
        final index =
        rawLabel.toInt();

        if (index >= 0 &&
            index < classNames.length) {
          return classNames[index];
        }
      }

      final text =
      rawLabel.toString().trim();

      final index =
      int.tryParse(text);

      if (index != null &&
          index >= 0 &&
          index < classNames.length) {
        return classNames[index];
      }

      if (text.isNotEmpty) {
        return _normalizeLabel(text);
      }
    }

    return 'desconocido';
  }

  // ============================================================
  // NORMALIZAR CLASE
  // ============================================================

  static String _normalizeLabel(
      String value) {
    final text =
    value.trim().toLowerCase();

    for (final className in classNames) {
      if (text ==
          className.toLowerCase()) {
        return className;
      }
    }

    return text;
  }

  // ============================================================
  // OBTENER BOUNDING BOX
  // ============================================================

  static List<double> _parseBbox(
      dynamic value) {
    if (value is Map) {
      final x1 = _toDouble(
        value['x1'] ??
            value['xmin'] ??
            value['left'],
      );

      final y1 = _toDouble(
        value['y1'] ??
            value['ymin'] ??
            value['top'],
      );

      final x2 = _toDouble(
        value['x2'] ??
            value['xmax'] ??
            value['right'],
      );

      final y2 = _toDouble(
        value['y2'] ??
            value['ymax'] ??
            value['bottom'],
      );

      if (x2 > x1 &&
          y2 > y1) {
        return [
          x1,
          y1,
          x2,
          y2,
        ];
      }

      final x =
      _toDouble(value['x']);

      final y =
      _toDouble(value['y']);

      final width =
      _toDouble(
        value['width'] ??
            value['w'],
      );

      final height =
      _toDouble(
        value['height'] ??
            value['h'],
      );

      if (width > 0 &&
          height > 0) {
        return [
          x,
          y,
          x + width,
          y + height,
        ];
      }
    }

    if (value is List &&
        value.length >= 4) {
      return [
        _toDouble(value[0]),
        _toDouble(value[1]),
        _toDouble(value[2]),
        _toDouble(value[3]),
      ];
    }

    return [
      0,
      0,
      0,
      0,
    ];
  }

  // ============================================================
  // CONVERTIR A DOUBLE
  // ============================================================

  static double _toDouble(
      dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0.0;
  }

  // ============================================================
  // COLOR DE CADA DEFECTO
  // ============================================================

  static Color colorForLabel(
      String label) {
    final cleanLabel =
    _normalizeLabel(label);

    switch (cleanLabel) {
      case 'agrio_parcial':
        return const Color(
          0xFFFFB300,
        );

      case 'broca_leve_severa':
        return const Color(
          0xFF795548,
        );

      case 'cereza_seca':
        return const Color(
          0xFFE65100,
        );

      case 'concha':
        return const Color(
          0xFF8E24AA,
        );

      case 'cortado':
        return const Color(
          0xFFE53935,
        );

      case 'grano_negro':
        return const Color(
          0xFF212121,
        );

      case 'negro_parcial':
        return const Color(
          0xFF546E7A,
        );

      case 'normal':
        return const Color(
          0xFF43A047,
        );

      case 'por_hongo':
        return const Color(
          0xFF00897B,
        );

      default:
        return const Color(
          0xFF1E88E5,
        );
    }
  }
}
