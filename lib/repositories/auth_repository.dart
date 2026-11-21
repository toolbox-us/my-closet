import '../models/user.dart';

/// Signup failure modes.
///
/// Enumerated so the UI can be built and tested against realistic failures
/// without a backend to produce them.
enum AuthFailureKind {
  emailAlreadyExists,
  invalidCredentials,
  network,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.kind, this.message);

  final AuthFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// The signed-in user, or null.
  Future<AppUser?> currentUser();

  /// Throws [AuthException] on failure.
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String genderPreference,
  });

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
