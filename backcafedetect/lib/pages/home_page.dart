import 'package:flutter/material.dart';
import 'detect_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const String unlLogo =
      'https://www.unl.edu.ec/sites/default/files/inline-images/unl_0_2.png';

  static const String carreraLogo =
      'https://i.postimg.cc/pdDTC3HR/carrera-unl.png';

  static const String defectosCafeImage =
      'https://i.postimg.cc/QN4skfct/CAFE.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.network(
                        unlLogo,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.school,
                            size: 60,
                            color: Color(0xFF6F4E37),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Image.network(
                    carreraLogo,
                    height: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Color(0xFF6F4E37),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Detector de Defectos\nFísicos en Granos de\nCafé',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Interfaz de prueba',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B6B5A),
                ),
              ),

              const SizedBox(height: 26),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Defectos considerados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),

                    const SizedBox(height: 18),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: Colors.white,
                        constraints: const BoxConstraints(
                          minHeight: 180,
                          maxHeight: 320,
                        ),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 5.0,
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          child: Image.network(
                            defectosCafeImage,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                                ) {
                              if (loadingProgress == null) return child;

                              return const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF6F4E37),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) {
                              return const SizedBox(
                                height: 220,
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No se pudo cargar la imagen de defectos.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Tesista: Cristian Yaguana',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4E342E),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B5537),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DetectPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'INICIAR DETECCIÓN',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}