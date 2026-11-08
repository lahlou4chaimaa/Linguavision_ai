
import 'package:supabase_flutter/supabase_flutter.dart';

class LearningService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> saveLearningProfile({
    required String nativeLanguage,
    required String targetLanguage,
    required String currentLevel,
    required String learningGoal,
    required int dailyMinutes,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    await _supabase.from('learning_profiles').upsert({
      'user_id': user.id,
      'native_language': nativeLanguage,
      'target_language': targetLanguage,
      'current_level': currentLevel,
      'learning_goal': learningGoal,
      'daily_minutes': dailyMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getLearningProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final response = await _supabase
        .from('learning_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return response;
  }
}
