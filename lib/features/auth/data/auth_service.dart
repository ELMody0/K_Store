import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign Up
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? emailRedirectTo,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: emailRedirectTo,
    );
  }

  // Check if full name is taken
  Future<bool> isFullNameTaken(String fullName) async {
    try {
      final normalized = fullName.trim().toLowerCase();
      
      // Query profiles table directly - most reliable method
      final response = await _supabase
          .from('profiles')
          .select('id, full_name')
          .ilike('full_name', normalized)
          .limit(1);
      
      if (response.isNotEmpty) {
        return true;
      }
      
      // Also try exact match in case ilike doesn't work as expected
      final exactResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('full_name', fullName.trim())
          .limit(1);
      
      return exactResponse.isNotEmpty;
    } catch (e) {
      // Silently fail - let Supabase handle duplicates during signUp
      return false;
    }
  }

  // Check if email is taken
  Future<bool> isEmailTaken(String email) async {
    try {
      final normalized = email.trim().toLowerCase();
      
      // Try RPC first if it exists
      try {
        final data = await _supabase.rpc('check_email_exists', params: {'email': normalized});
        if (data == true) return true;
      } catch (_) {
        // RPC doesn't exist, continue with fallback
      }
      
      // Note: We can't directly query auth.users from client side
      // Email uniqueness will be enforced by Supabase during signUp
      // This check is best-effort only
      return false;
    } catch (e) {
      // Silently fail - email uniqueness enforced by Supabase
      return false;
    }
  }

  // Sign In
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is logged in
  Session? get currentSession => _supabase.auth.currentSession;
}
