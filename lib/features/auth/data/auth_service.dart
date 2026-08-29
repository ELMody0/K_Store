import 'package:flutter/foundation.dart';
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
      // لو حصل خطأ (مثلاً مفيش نت)، نرجّع false ونطبع الخطأ بدل ما نخفيّه في صمت
      debugPrint('isFullNameTaken error: $e');
      return false;
    }
  }

  // Check if email is taken
  // ملاحظة: الإيميل موجود فقط في auth.users (مقيد الوصول)، فمقدرش نتأكد من الكلاينت مباشرة.
  // أفضل ممارسة: نعتمد على رفض Supabase وقت signUp (معالَج في signup_page).
  // الدالة دي بتحاول RPC لو موجود، وإلا ترجّع false (best-effort).
  Future<bool> isEmailTaken(String email) async {
    final normalized = email.trim().toLowerCase();
    try {
      final data = await _supabase.rpc('check_email_exists', params: {'p_email': normalized});
      if (data == true) return true;
    } catch (_) {
      // RPC غير متاح أو مقيّد — نسيبها false ونعتمد على signUp برفض المكرر
    }
    return false;
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

  // Reset password (send reset link to email)
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is logged in
  Session? get currentSession => _supabase.auth.currentSession;
}
