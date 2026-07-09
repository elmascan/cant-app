import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;


class VisionModerationService {
  static const _apiKey = String.fromEnvironment(
    'VISION_API_KEY',
    defaultValue: '',
  );

  static const _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  // Ratings that trigger rejection for adult/violence
  static const _blocked = {'LIKELY', 'VERY_LIKELY'};

  /// Returns true if the image is safe to upload, false if it violates guidelines.
  /// Fails open (returns true) on API/network errors to avoid blocking users.
  
  static Future<bool> isSafe(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requests': [
                {
                  'image': {'content': base64Image},
                  'features': [
                    {'type': 'SAFE_SEARCH_DETECTION'}
                  ],
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return true;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final annotations = data['responses']?[0]?['safeSearchAnnotation']
          as Map<String, dynamic>?;
      if (annotations == null) return true;

      final adult = annotations['adult'] as String? ?? 'UNKNOWN';
      final violence = annotations['violence'] as String? ?? 'UNKNOWN';
      final racy = annotations['racy'] as String? ?? 'UNKNOWN';

      if (_blocked.contains(adult)) return false;
      if (_blocked.contains(violence)) return false;
      if (racy == 'VERY_LIKELY') return false;

      return true;
    } catch (_) {
      return true;
    }
  }
}
