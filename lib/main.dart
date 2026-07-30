import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color cafeOscuro = Color(0xFF6F4E37);
  static const Color fondo = Color(0xFFF5F0E6);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector de Café',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: fondo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cafeOscuro,
          primary: cafeOscuro,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: fondo,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: Color(0xFF4E342E),
          ),
          titleTextStyle: TextStyle(
            color: Color(0xFF4E342E),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}