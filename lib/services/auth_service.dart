import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_logging_service.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  final _activityLoggingService = ActivityLoggingService();

  // Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'username': username} : null,
      );

      // Log signup activity if user is created
      if (response.user != null) {
        await _activityLoggingService.logActivity(
          userId: response.user!.id,
          activityType: ActivityType.login,
          additionalDetails: {
            'email': email,
            'registration_method': 'email_password'
          }
        );
      }

      return response;
    } on AuthException catch (e) {
      // Log signup failure
      await _activityLoggingService.logActivity(
        userId: 'unknown',
        activityType: ActivityType.login,
        additionalDetails: {
          'email': email,
          'error': e.message,
          'registration_status': 'failed'
        }
      );
      throw Exception('Sign Up Error: ${e.message}');
    }
  }

  // Sign In
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Log login activity
      if (response.user != null) {
        await _activityLoggingService.logActivity(
          userId: response.user!.id,
          activityType: ActivityType.login,
          additionalDetails: {
            'email': email,
            'login_method': 'email_password'
          }
        );
      }

      return response;
    } on AuthException catch (e) {
      // Log login failure
      await _activityLoggingService.logActivity(
        userId: 'unknown',
        activityType: ActivityType.login,
        additionalDetails: {
          'email': email,
          'error': e.message,
          'login_status': 'failed'
        }
      );
      throw Exception('Sign In Error: ${e.message}');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final currentUser = getCurrentUser();
    
    try {
      await _supabase.auth.signOut();

      // Log logout activity if user was logged in
      if (currentUser != null) {
        await _activityLoggingService.logActivity(
          userId: currentUser.id,
          activityType: ActivityType.logout,
          additionalDetails: {
            'email': currentUser.email
          }
        );
      }
    } catch (e) {
      // Log logout failure
      await _activityLoggingService.logActivity(
        userId: currentUser?.id ?? 'unknown',
        activityType: ActivityType.logout,
        additionalDetails: {
          'error': e.toString(),
          'logout_status': 'failed'
        }
      );
      rethrow;
    }
  }

  // Get Current User
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Check Authentication Status
  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }
}
