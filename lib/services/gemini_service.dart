import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GeminiService {
  final String apiKey;
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1/models';

  GeminiService(this.apiKey);

  Future<String> analyzeImage(
    File imageFile,
    String prompt, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Read image as base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Build prompt with location context if available
      String fullPrompt = prompt;
      if (latitude != null && longitude != null) {
        fullPrompt += '\n\nKonteks lokasi: Latitude $latitude, Longitude $longitude';
      }

      // Prepare request - Use gemini-1.5-flash or gemini-1.5-pro
      final url = Uri.parse(
        '$baseUrl/gemini-1.5-flash:generateContent?key=$apiKey',
      );

      debugPrint('Sending request to: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 2048,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check if response has candidates
        if (data['candidates'] == null || data['candidates'].isEmpty) {
          return 'AI tidak dapat memberikan respons untuk gambar ini.';
        }
        
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        return text ?? 'Tidak ada respons dari AI';
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Permintaan tidak valid';
        throw Exception('Permintaan tidak valid: $errorMessage');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Kunci A P I tidak valid atau tidak memiliki akses. Periksa pengaturan A P I.');
      } else if (response.statusCode == 404) {
        throw Exception('Model tidak ditemukan. Pastikan menggunakan model yang benar.');
      } else if (response.statusCode == 429) {
        throw Exception('Terlalu banyak permintaan. Silakan coba lagi nanti.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server sedang bermasalah. Silakan coba lagi nanti.');
      } else {
        throw Exception('Kesalahan tidak diketahui: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in analyzeImage: $e');
      throw Exception('Error menganalisis gambar: $e');
    }
  }
}