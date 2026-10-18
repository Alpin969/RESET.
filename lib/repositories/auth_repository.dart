import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';
import 'profile_repository.dart';

class AuthRepository {
  AuthRepository({AuthService? authService, ProfileRepository? profileRepository})
      : _auth = authService ?? AuthService(),
        _profiles = profileRepository ?? ProfileRepository();

  final AuthService _auth;
  final ProfileRepository _profiles;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;
  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final normalizedUsername = normalizeUsername(username);

    validateUsername(normalizedUsername);
    validateEmail(email);
    validatePassword(password);

    if (password != confirmPassword) {
      throw AuthException('Konfirmasi password tidak sama.');
    }

    final available = await _profiles.isUsernameAvailable(normalizedUsername);
    if (!available) {
      throw AuthException('Username sudah digunakan.');
    }

    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': normalizedUsername},
    );
  }

  Future<User?> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedOtp = otp.trim();

    validateEmail(normalizedEmail);

    if (normalizedOtp.isEmpty) {
      throw AuthException('Kode OTP wajib diisi.');
    }

    if (!RegExp(r'^\d{6}$').hasMatch(normalizedOtp)) {
      throw AuthException('Kode OTP harus 6 digit angka.');
    }

    final response = await _auth.verifySignupOtp(
      email: normalizedEmail,
      token: normalizedOtp,
    );
    return response.user;
  }

  Future<void> resendSignupOtp({required String email}) {
    final normalizedEmail = email.trim();

    validateEmail(normalizedEmail);

    return _auth.resendSignupOtp(email: normalizedEmail);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || password.isEmpty) {
      throw AuthException('Email dan password wajib diisi.');
    }
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    if (email.trim().isEmpty) {
      throw AuthException('Email wajib diisi.');
    }
    return _auth.resetPasswordForEmail(email.trim());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw AuthException('Sesi tidak ditemukan. Silakan login ulang.');
    }

    validatePassword(newPassword);

    if (currentPassword.isEmpty) {
      throw AuthException('Password lama wajib diisi.');
    }

    if (currentPassword == newPassword) {
      throw AuthException('Password baru harus berbeda dari password lama.');
    }

    await _auth.signInWithPassword(email: email, password: currentPassword);
    await _auth.updatePassword(newPassword);
  }

  String normalizeUsername(String username) {
    return Validators.normalizeUsername(username);
  }

  void validateUsername(String username) {
    if (!Validators.isValidUsername(username)) {
      throw AuthException(
        'Username 3-20 karakter, hanya huruf kecil, angka, dan underscore.',
      );
    }
  }

  void validateEmail(String email) {
    if (!Validators.isValidEmail(email)) {
      throw AuthException('Format email tidak valid.');
    }
  }

  void validatePassword(String password) {
    if (!Validators.isValidPassword(password)) {
      throw AuthException('Password minimal 6 karakter.');
    }
  }
}

final authRepository = AuthRepository();
