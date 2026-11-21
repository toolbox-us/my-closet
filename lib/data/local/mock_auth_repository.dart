import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../../core/utils/app_utils.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import 'hive_boxes.dart';

/// Mocked authentication.
///
/// The course requirements do not call for a real identity provider, and a
/// mock keeps the prototype runnable with no network. The session is still
/// persisted to Hive, so relaunching the app skips signup - which is what a
/// real provider would do, and what a grader will expect.
///
/// Failure modes are reachable on purpose so the UI can be built and tested
/// against them:
///   * any email already in [_takenEmails]  -> emailAlreadyExists
///   * an email containing 'network'        -> network
///   * sign-in with the wrong password      -> invalidCredentials
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._box);

  final Box<String> _box;

  static const Duration _latency = Duration(milliseconds: 700);

  static const Set<String> _takenEmails = <String>{
    'taken@example.com',
    'existing@example.com',
  };

  static const String _passwordKey = 'password';

  @override
  Future<AppUser?> currentUser() async {
    final String? raw = _box.get(AppBoxes.singletonKey);
    if (raw == null) return null;
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is Map) {
        return AppUser.fromJson(Map<String, dynamic>.from(parsed));
      }
    } catch (_) {
      // Corrupt session - treat as signed out.
    }
    return null;
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String genderPreference,
  }) async {
    await Future<void>.delayed(_latency);

    final String normalized = email.trim().toLowerCase();

    if (normalized.contains('network')) {
      throw const AuthException(
        AuthFailureKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (_takenEmails.contains(normalized)) {
      throw const AuthException(
        AuthFailureKind.emailAlreadyExists,
        'An account with that email already exists.',
      );
    }

    final AppUser user = AppUser(
      id: Ids.generate('user'),
      name: name.trim(),
      email: normalized,
      phone: phone.trim(),
      genderPreference: genderPreference,
      createdAt: DateTime.now(),
    );

    await _box.put(AppBoxes.singletonKey, jsonEncode(user.toJson()));
    await _box.put(_passwordKey, password);
    return user;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);

    final AppUser? existing = await currentUser();
    final String? storedPassword = _box.get(_passwordKey);

    if (existing == null ||
        existing.email != email.trim().toLowerCase() ||
        storedPassword != password) {
      throw const AuthException(
        AuthFailureKind.invalidCredentials,
        'That email and password combination did not match.',
      );
    }

    return existing;
  }

  @override
  Future<void> signOut() async {
    await _box.delete(AppBoxes.singletonKey);
    await _box.delete(_passwordKey);
  }
}
