import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../painters/detection_painter.dart';

class ResultPage extends StatefulWidget {
  final File image;
  final Map<String, dynamic> response;

  // Confianza obtenida del primer modelo:
  // https://javiersarango-roast-api.hf.space/predict
  final double coffeeConfidence;

  const ResultPage({
    super.key,
    required this.image,
    required this.response,
    required this.coffeeConfidence,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  // Todas las detecciones recibidas del backend.
  late final List<Detection> detections;

  // Detecciones finales:
  // una sola por grano, conservando la de mayor confianza.
  late final List<Detection> uniqueGrains;

  late final Future<ui.Image> imageFuture;

  @override
  void initState() {
    super.initState();

    // Obtener todas las detecciones originales.
    detections = Detection.listFromResponse(widget.response);

    // Eliminar detecciones que pertenecen al mismo grano.
    // Se conserva solamente la de mayor confianza.
    uniqueGrains = _getUniqueGrains(detections);

    // Cargar la imagen para dibujar los boxes.
    imageFuture = _loadUiImage(widget.image);
  }

  // ============================================================
  // CARGAR IMAGEN
  // ============================================================

  Future<ui.Image> _loadUiImage(File file) async {
    final bytes = await file.readAsBytes();

    final codec = await ui.instantiateImageCodec(bytes);

    final frame = await codec.getNextFrame();

    return frame.image;
  }

 
  List<Detection> _getUniqueGrains(
      List<Detection> detections,
      ) {
    // Ignorar detecciones sin box válido.
    final validDetections = detections
        .where((detection) => detection.hasValidBox)
        .toList();

    // Cada elemento de groups representa un grano.
    final List<List<Detection>> groups = [];

    for (final detection in validDetections) {
      int? matchingGroupIndex;

      // Buscar si esta detección pertenece a un grano
      // que ya fue encontrado.
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];

        final sameGrain = group.any(
              (existingDetection) {
            return _areSameGrain(
              existingDetection,
              detection,
            );
          },
        );

        if (sameGrain) {
          matchingGroupIndex = i;
          break;
        }
      }

      // Si no pertenece a ningún grupo,
      // crear un nuevo grano.
      if (matchingGroupIndex == null) {
        groups.add([detection]);
      } else {
        // Si pertenece a un grupo existente,
        // agregarla al mismo grano.
        groups[matchingGroupIndex].add(detection);
      }
    }

    // ==========================================================
    // CONSERVAR SOLO LA MAYOR CONFIANZA DE CADA GRANO
    // ==========================================================

    final List<Detection> unique = [];

    for (final group in groups) {
      Detection bestDetection = group.first;

      for (final detection in group) {
        if (detection.confidence >
            bestDetection.confidence) {
          bestDetection = detection;
        }
      }

      unique.add(bestDetection);
    }

    return unique;
  }

  // ============================================================
  // DETERMINAR SI DOS DETECCIONES SON DEL MISMO GRANO
  // ============================================================
  //

  bool _areSameGrain(
      Detection a,
      Detection b,
      ) {
    final aWidth = (a.x2 - a.x1).abs();
    final aHeight = (a.y2 - a.y1).abs();

    final bWidth = (b.x2 - b.x1).abs();
    final bHeight = (b.y2 - b.y1).abs();

    if (aWidth <= 0 ||
        aHeight <= 0 ||
        bWidth <= 0 ||
        bHeight <= 0) {
      return false;
    }

    // ==========================================================
    // 1. COORDENADAS SIMILARES
    // ==========================================================

    final maxWidth =
    aWidth > bWidth ? aWidth : bWidth;

    final maxHeight =
    aHeight > bHeight ? aHeight : bHeight;

    // Tolerancia del 25%.
    //
    // Esto permite que pequeñas diferencias en las coordenadas
    // sigan considerándose el mismo grano.
    final toleranceX = maxWidth * 0.25;
    final toleranceY = maxHeight * 0.25;

    final similarCoordinates =
        (a.x1 - b.x1).abs() <= toleranceX &&
            (a.y1 - b.y1).abs() <= toleranceY &&
            (a.x2 - b.x2).abs() <= toleranceX &&
            (a.y2 - b.y2).abs() <= toleranceY;

    if (similarCoordinates) {
      return true;
    }

    // ==========================================================
    // 2. CALCULAR INTERSECCIÓN
    // ==========================================================

    final intersectionLeft =
    a.x1 > b.x1 ? a.x1 : b.x1;

    final intersectionTop =
    a.y1 > b.y1 ? a.y1 : b.y1;

    final intersectionRight =
    a.x2 < b.x2 ? a.x2 : b.x2;

    final intersectionBottom =
    a.y2 < b.y2 ? a.y2 : b.y2;

    final intersectionWidth =
        intersectionRight - intersectionLeft;

    final intersectionHeight =
        intersectionBottom - intersectionTop;

    double intersectionArea = 0;

    if (intersectionWidth > 0 &&
        intersectionHeight > 0) {
      intersectionArea =
          intersectionWidth * intersectionHeight;
    }

    // ==========================================================
    // 3. ÁREAS
    // ==========================================================

    final areaA =
        aWidth * aHeight;

    final areaB =
        bWidth * bHeight;

    final unionArea =
        areaA +
            areaB -
            intersectionArea;

    // ==========================================================
    // 4. IoU
    // ==========================================================

    double iou = 0;

    if (unionArea > 0) {
      iou =
          intersectionArea /
              unionArea;
    }

    if (iou >= 0.30) {
      return true;
    }

    // ==========================================================
    // 5. CONTENCIÓN
    // ==========================================================


    final smallerArea =
    areaA < areaB
        ? areaA
        : areaB;

    if (smallerArea > 0) {
      final containment =
          intersectionArea /
              smallerArea;


      if (containment >= 0.60) {
        return true;
      }
    }

    // ==========================================================
    // 6. DISTANCIA ENTRE CENTROS
    // ==========================================================

    final centerAX =
        (a.x1 + a.x2) / 2;

    final centerAY =
        (a.y1 + a.y2) / 2;

    final centerBX =
        (b.x1 + b.x2) / 2;

    final centerBY =
        (b.y1 + b.y2) / 2;

    final distanceX =
    (centerAX - centerBX).abs();

    final distanceY =
    (centerAY - centerBY).abs();

    final averageWidth =
        (aWidth + bWidth) / 2;

    final averageHeight =
        (aHeight + bHeight) / 2;

    final centersAreClose =
        distanceX <=
            averageWidth * 0.50 &&
            distanceY <=
                averageHeight * 0.50;

  
    if (centersAreClose &&
        iou >= 0.10) {
      return true;
    }

    return false;
  }

  // ============================================================
  // ESTADÍSTICAS
  // ============================================================

  Map<String, int> _buildStats() {
    final Map<String, int> stats = {};

    for (final detection in uniqueGrains) {
      stats[detection.label] =
          (stats[detection.label] ?? 0) + 1;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _buildStats();

    // ==========================================================
    // NÚMERO REAL DE GRANOS
    // ==========================================================
  
    final total = uniqueGrains.length;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F0E6),

      appBar: AppBar(
        title: const Text('Resultados'),
      ),

      body: Padding(
        padding:
        const EdgeInsets.all(16),

        child: Column(
          children: [

            // ==================================================
            // IMAGEN CON BOXES
            // ==================================================

            Expanded(
              flex: 5,

              child: FutureBuilder<ui.Image>(
                future: imageFuture,

                builder:
                    (context, snapshot) {

                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        Color(0xFF6F4E37),
                      ),
                    );
                  }

                  return Container(
                    width:
                    double.infinity,

                    decoration:
                    BoxDecoration(
                      color: Colors.white,

                      borderRadius:
                      BorderRadius.circular(
                        22,
                      ),

                      boxShadow: const [
                        BoxShadow(
                          color:
                          Colors.black12,
                          blurRadius: 8,
                          offset:
                          Offset(0, 4),
                        ),
                      ],
                    ),

                    child: ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                        22,
                      ),

                      child:
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 6.0,
                        panEnabled: true,

                        child: Stack(
                          fit: StackFit.expand,

                          children: [

                            // Imagen original
                            Image.file(
                              widget.image,
                              fit: BoxFit.contain,
                            ),

                          

                            CustomPaint(
                              painter:
                              DetectionPainter(
                                detections:
                                uniqueGrains,

                                image:
                                snapshot.data!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // CONTEO DE GRANOS
            // ==================================================

            Align(
              alignment:
              Alignment.centerLeft,

              child: Text(
                'Número de granos de café detectados: $total',

                style:
                const TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  Color(0xFF4E342E),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // CUADRADOS / ESTADÍSTICAS
            // ==================================================

            Expanded(
              flex: 4,

              child: stats.isEmpty

                  ? const Center(
                child: Text(
                  'No se recibieron detecciones del backend.',

                  textAlign:
                  TextAlign.center,

                  style:
                  TextStyle(
                    color:
                    Colors.black54,
                  ),
                ),
              )

                  : GridView.builder(
                itemCount:
                stats.length,

                padding:
                EdgeInsets.zero,

                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,

                  crossAxisSpacing:
                  12,

                  mainAxisSpacing:
                  12,

                  mainAxisExtent:
                  160,
                ),

                itemBuilder:
                    (context, index) {

                  final entry =
                  stats.entries
                      .elementAt(
                    index,
                  );

                  return _ClassStatCard(
                    label:
                    entry.key,

                    count:
                    entry.value,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TARJETA DE CADA DEFECTO
// ================================================================

class _ClassStatCard
    extends StatelessWidget {

  final String label;
  final int count;

  const _ClassStatCard({
    required this.label,
    required this.count,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final color =
    Detection.colorForLabel(
      label,
    );

    final displayName =
        Detection(
          label: label,
          confidence: 0,
          x1: 0,
          y1: 0,
          x2: 0,
          y2: 0,
        ).displayLabel;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),

      decoration:
      BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        border: Border.all(
          color: color,
          width: 2,
        ),

        boxShadow: const [
          BoxShadow(
            color:
            Colors.black12,
            blurRadius: 4,
            offset:
            Offset(0, 2),
          ),
        ],
      ),

      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [

          // Círculo del color del defecto
          Container(
            width: 18,
            height: 18,

            decoration:
            BoxDecoration(
              color: color,
              shape:
              BoxShape.circle,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // ==================================================
          // NÚMERO
          // ==================================================

          Text(
            '$count',

            textAlign:
            TextAlign.center,

            style: TextStyle(
              fontSize: 24,
              fontWeight:
              FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // ==================================================
          // NOMBRE DEL DEFECTO
          // ==================================================

          Text(
            displayName,

            textAlign:
            TextAlign.center,

            maxLines: 2,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              fontSize: 12.5,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
