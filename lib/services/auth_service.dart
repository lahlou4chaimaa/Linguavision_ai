import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Modifier le nom de l'utilisateur
  Future<void> updateFullName(String fullName) async {
    await _supabase.auth.updateUser(
      UserAttributes(data: {'full_name': fullName.trim()}),
    );
  }

  // Modifier le mot de passe
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  User? get currentUser => _supabase.auth.currentUser;

  bool get isLoggedIn => _supabase.auth.currentSession != null;
}
