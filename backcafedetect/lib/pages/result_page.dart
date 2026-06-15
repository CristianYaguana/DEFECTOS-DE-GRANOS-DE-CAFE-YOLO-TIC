import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../painters/detection_painter.dart';

class ResultPage extends StatefulWidget {
  final File image;
  final Map<String, dynamic> response;

  const ResultPage({
    super.key,
    required this.image,
    required this.response,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late final List<Detection> detections;
  late final Future<ui.Image> imageFuture;

  @override
  void initState() {
    super.initState();
    detections = Detection.listFromResponse(widget.response);
    imageFuture = _loadUiImage(widget.image);
  }

  Future<ui.Image> _loadUiImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Map<String, int> _buildStats() {
    final Map<String, int> stats = {};

    for (final detection in detections) {
      stats[detection.label] = (stats[detection.label] ?? 0) + 1;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _buildStats();
    final total = Detection.totalFromResponse(widget.response);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        title: const Text('Resultados'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: FutureBuilder<ui.Image>(
                future: imageFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6F4E37),
                      ),
                    );
                  }

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 6.0,
                        panEnabled: true,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              widget.image,
                              fit: BoxFit.contain,
                            ),
                            CustomPaint(
                              painter: DetectionPainter(
                                detections: detections,
                                image: snapshot.data!,
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

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Número de granos de café detectados: $total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              flex: 4,
              child: stats.isEmpty
                  ? const Center(
                child: Text(
                  'No se recibieron detecciones del backend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              )
                  : GridView.builder(
                itemCount: stats.length,
                padding: EdgeInsets.zero,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 160,
                ),
                itemBuilder: (context, index) {
                  final entry = stats.entries.elementAt(index);

                  return _ClassStatCard(
                    label: entry.key,
                    count: entry.value,
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

class _ClassStatCard extends StatelessWidget {
  final String label;
  final int count;

  const _ClassStatCard({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = Detection.colorForLabel(label);

    final displayName = Detection(
      label: label,
      confidence: 0,
      x1: 0,
      y1: 0,
      x2: 0,
      y2: 0,
      mask: const [],
    ).displayLabel;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}