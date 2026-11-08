
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'learning_service.dart';

class AiTutorService {
  // URL du backend local.
  // Pour Flutter Web sur le même ordinateur :
  // http://127.0.0.1:8000
  //
  // Pour Android Emulator, utiliser :
  // http://10.0.2.2:8000
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final LearningService _learningService = LearningService();

  Future<String> sendMessage({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      // Récupération du profil linguistique depuis Supabase.
      final profile = await _learningService.getLearningProfile();

      final nativeLanguage =
          profile?['native_language'] ?? 'French';

      final targetLanguage =
          profile?['target_language'] ?? 'English';

      final level =
          profile?['current_level'] ?? 'A1';

      final learningGoal =
          profile?['learning_goal'] ?? 'Daily communication';

      final uri = Uri.parse('$_baseUrl/api/tutor/chat');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': message,
              'native_language': nativeLanguage,
              'target_language': targetLanguage,
              'level': level,
              'learning_goal': learningGoal,
              'history': history.take(12).toList(),
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data['reply'] as String;
      }

      throw Exception(
        'Server error ${response.statusCode}: ${response.body}',
      );
    } catch (error) {
      throw Exception('Unable to contact the AI Tutor: $error');
    }
  }
}
