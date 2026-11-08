import 'package:supabase_flutter/supabase_flutter.dart';

class TutorHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    return user.id;
  }

  // Create a new conversation
  Future<String> createConversation({String title = 'New conversation'}) async {
    final result = await _supabase
        .from('tutor_conversations')
        .insert({'user_id': _userId, 'title': title})
        .select('id')
        .single();

    return result['id'] as String;
  }

  // Save a message
  Future<void> saveMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    if (role != 'user' && role != 'assistant') {
      throw ArgumentError('Invalid message role.');
    }

    await _supabase.from('tutor_messages').insert({
      'conversation_id': conversationId,
      'user_id': _userId,
      'role': role,
      'content': content,
    });

    await _supabase
        .from('tutor_conversations')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId)
        .eq('user_id', _userId);
  }

  // Get all conversations
  Future<List<Map<String, dynamic>>> getConversations() async {
    final result = await _supabase
        .from('tutor_conversations')
        .select()
        .eq('user_id', _userId)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }

  // Get messages from one conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final result = await _supabase
        .from('tutor_messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', _userId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(result);
  }

  // Rename a conversation
  Future<void> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    await _supabase
        .from('tutor_conversations')
        .update({'title': title})
        .eq('id', conversationId)
        .eq('user_id', _userId);
  }

  // Delete a conversation and its messages
  Future<void> deleteConversation(String conversationId) async {
    await _supabase
        .from('tutor_conversations')
        .delete()
        .eq('id', conversationId)
        .eq('user_id', _userId);
  }
}
