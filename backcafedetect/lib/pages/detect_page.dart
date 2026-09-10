import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'result_page.dart';

class DetectPage extends StatefulWidget {
  const DetectPage({super.key});

  @override
  State<DetectPage> createState() => _DetectPageState();
}

class _DetectPageState extends State<DetectPage> {
  File? image;
  bool isLoading = false;

  Future<void> pickImage(
      ImageSource source,
      ) async {
    final picker = ImagePicker();

    final pickedImage =
    await picker.pickImage(
      source: source,
      imageQuality: 95,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      image = File(
        pickedImage.path,
      );
    });
  }

  // ============================================================
  // OBTENER CONFIANZA DEL CLASIFICADOR
  // ============================================================
  double _getCoffeeConfidence(
      Map<String, dynamic> response,
      ) {
    final value =
        response['confidence'] ??
            response['confianza'] ??
            response['probability'] ??
            response['probabilidad'] ??
            response['score'] ??
            0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0.0;
  }

  // ============================================================
  // DETERMINAR CLASE
  // ============================================================
  String _getPredictedClass(
      Map<String, dynamic> response,
      ) {
    final value =
        response['clase_predicha'] ??
            response['class'] ??
            response['label'] ??
            response['clase'] ??
            '';

    return value.toString().trim();
  }

  // ============================================================
  // ANALIZAR IMAGEN
  // ============================================================
  Future<void> analyzeImage() async {
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero seleccione una imagen.',
          ),
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ========================================================
      // PASO 1:
      // PRIMERO DETERMINAMOS SI ES CAFÉ.
      // ========================================================
      final coffeeResponse =
      await ApiService.classifyCoffee(
        image!,
      );

      final predictedClass =
      _getPredictedClass(
        coffeeResponse,
      );

      final coffeeConfidence =
      _getCoffeeConfidence(
        coffeeResponse,
      );

      final confidencePercentage =
      coffeeConfidence <= 1
          ? coffeeConfidence * 100
          : coffeeConfidence;

      // ========================================================
      // PASO 2:
      // SOLO "Green" PUEDE CONTINUAR.
      // ========================================================
      if (predictedClass.toLowerCase() !=
          'green') {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .hideCurrentSnackBar();

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'No es café. Suba otra fotografía '
                  'que corresponda a granos de café.\n',
            ),
            duration:
            const Duration(seconds: 5),
            behavior:
            SnackBarBehavior.floating,
            margin:
            const EdgeInsets.all(16),
            backgroundColor:
            const Color(0xFF4E342E),
          ),
        );

        // MUY IMPORTANTE:
        // NO LLAMAMOS AL DETECTOR DE DEFECTOS.
        return;
      }

      // ========================================================
      // PASO 3:
      // LLEGAMOS AQUÍ ÚNICAMENTE SI ES "Green".
      // ========================================================
      final response =
      await ApiService.predict(
        image!,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // PASO 4:
      // MOSTRAR RESULTADOS DE DEFECTOS.
      // ========================================================
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            image: image!,
            response: response,
            coffeeConfidence:
            confidencePercentage,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al analizar la imagen: $e',
          ),
          backgroundColor: Colors.red,
          behavior:
          SnackBarBehavior.floating,
          margin:
          const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final canAnalyze =
        image != null && !isLoading;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F0E6),
      appBar: AppBar(
        title: const Text(
          'Captura de Imagen',
        ),
      ),
      body: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration:
                BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: image == null
                    ? const Column(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 85,
                      color:
                      Color(0xFF6F4E37),
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    Text(
                      '¡Listo para analizar!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        Color(0xFF4E342E),
                      ),
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      'Seleccione o capture una imagen\n'
                          'de granos de café.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                        Colors.black54,
                      ),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  child: Image.file(
                    image!,
                    width:
                    double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [
                Expanded(
                  child:
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.photo,
                    ),
                    label: const Text(
                      'Galería',
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.white,
                      foregroundColor:
                      const Color(
                        0xFF6F4E37,
                      ),
                      minimumSize:
                      const Size(
                        double.infinity,
                        55,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : () => pickImage(
                      ImageSource
                          .gallery,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.camera_alt,
                    ),
                    label: const Text(
                      'Cámara',
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.white,
                      foregroundColor:
                      const Color(
                        0xFF6F4E37,
                      ),
                      minimumSize:
                      const Size(
                        double.infinity,
                        55,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : () => pickImage(
                      ImageSource
                          .camera,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            SizedBox(
              width: double.infinity,
              height: 58,
              child:
              ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.search,
                ),
                label: Text(
                  isLoading
                      ? 'Analizando...'
                      : 'ANALIZAR IMAGEN',
                  style:
                  const TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(
                    0xFF6F4E37,
                  ),
                  foregroundColor:
                  Colors.white,
                  disabledBackgroundColor:
                  Colors.grey,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                onPressed:
                canAnalyze
                    ? analyzeImage
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
