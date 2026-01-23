import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // ============================================
  // REGISTER - Create new user
  // ============================================
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'user', // Default role is 'user'
  }) async {
    try {
      // Sign up with Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
      );

      if (response.user != null) {
        // User profile will be automatically created by database trigger
        // Check if trigger created the profile
        await Future.delayed(const Duration(milliseconds: 500));
        
        final profileCheck = await _supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (profileCheck == null) {
          // If trigger failed, create manually
          await _supabase.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
            'role': role,
          });
        }
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  // ============================================
  // LOGIN - Sign in existing user
  // ============================================
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  // ============================================
  // LOGOUT - Sign out current user
  // ============================================
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Logout failed: ${e.toString()}');
    }
  }

  // ============================================
  // PASSWORD RESET - Send reset email
  // ============================================
  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Password reset failed: ${e.toString()}');
    }
  }

  // ============================================
  // UPDATE PASSWORD - Change user password
  // ============================================
  Future<UserResponse> updatePassword({
    required String newPassword,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Password update failed: ${e.toString()}');
    }
  }

  // ============================================
  // UPDATE EMAIL - Change user email
  // ============================================
  Future<UserResponse> updateEmail({
    required String newEmail,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Email update failed: ${e.toString()}');
    }
  }

  // ============================================
  // GET USER PROFILE - Fetch from users table
  // ============================================
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // ============================================
  // UPDATE USER PROFILE - Update users table
  // ============================================
  Future<void> updateUserProfile({
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (phone != null) updates['phone'] = phone;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('users')
          .update(updates)
          .eq('id', currentUser!.id);

      // Also try to keep Auth user metadata in sync (non-fatal)
      try {
        final meta = <String, dynamic>{};
        if (fullName != null) meta['full_name'] = fullName;
        if (avatarUrl != null) meta['avatar_url'] = avatarUrl;
        if (meta.isNotEmpty) {
          await _supabase.auth.updateUser(UserAttributes(data: meta));
        }
      } catch (_) {
        // ignore — some providers/accounts may not allow metadata updates
      }
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // ============================================
  // CHECK IF USER IS ADMIN
  // ============================================
  Future<bool> isAdmin() async {
    try {
      if (currentUser == null) return false;

      final profile = await getUserProfile();
      return profile?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // GET USER ROLE
  // ============================================
  Future<String> getUserRole() async {
    final user = _supabase.auth.currentUser;
      if (user == null) return 'guest';

      final res = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      return res['role'] as String;
  }

  // ============================================
  // VERIFY EMAIL - Resend verification email
  // ============================================
  Future<void> resendVerificationEmail() async {
    try {
      if (currentUser == null || currentUser!.email == null) {
        throw Exception('No user logged in');
      }

      await _supabase.auth.resend(
        type: OtpType.signup,
        email: currentUser!.email!,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Failed to resend verification: ${e.toString()}');
    }
  }

  // ============================================
  // CHECK EMAIL VERIFIED
  // ============================================
  bool isEmailVerified() {
    return currentUser?.emailConfirmedAt != null;
  }

  // ============================================
  // REFRESH SESSION
  // ============================================
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Failed to refresh session: ${e.toString()}');
    }
  }

  // ============================================
  // DELETE ACCOUNT
  // ============================================
  Future<void> deleteAccount() async {
    try {
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Delete from users table (will cascade to orders, etc)
      await _supabase
          .from('users')
          .delete()
          .eq('id', currentUser!.id);

      // Sign out
      await logout();
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // ============================================
  // STREAM AUTH STATE CHANGES
  // ============================================
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}