import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  static const String predictUrl = 'https://crissyagg2001-cafe.hf.space/predict';

  static Future<Map<String, dynamic>> predict(File imageFile) async {
    final uri = Uri.parse(predictUrl);

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Error del backend: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('La respuesta del backend no es un JSON válido.');
    }

    return decoded;
  }
}