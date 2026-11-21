import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/data/memory/in_memory_repositories.dart';
import 'package:my_closet/features/auth/signup_screen.dart';
import 'package:my_closet/models/user.dart';
import 'package:my_closet/providers/providers.dart';
import 'package:my_closet/repositories/auth_repository.dart';

/// Widget tests run against the in-memory repositories, so no Hive
/// initialisation and no disk I/O is involved. This is what the in-memory
/// implementations are now for.
void main() {
  Widget harness() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
        profileRepositoryProvider
            .overrideWithValue(InMemoryProfileRepository()),
      ],
      child: const MaterialApp(home: SignupScreen()),
    );
  }

  group('signup validation', () {
    testWidgets('an empty form reports every required field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Confirm your password'), findsOneWidget);
    });

    testWidgets('a malformed email is rejected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'not-an-email',
      );
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('a short phone number is rejected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(2), '12345');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter at least 10 digits'), findsOneWidget);
    });

    testWidgets('a weak password reports the specific rule broken', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(3), 'abc');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 8 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(3), 'abcdefgh');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Include at least one number'), findsOneWidget);
    });

    testWidgets('mismatched passwords are caught', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(3), 'password1');
      await tester.enterText(find.byType(TextFormField).at(4), 'password2');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('a valid form reports no validation errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        '5551234567',
      );
      await tester.enterText(find.byType(TextFormField).at(3), 'password1');
      await tester.enterText(find.byType(TextFormField).at(4), 'password1');

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Enter a valid email address'), findsNothing);
      expect(find.text('Passwords do not match'), findsNothing);

      // Let the mocked latency and the subsequent navigation attempt settle.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('mocked auth failure modes reach the UI', () {
    testWidgets('a duplicate email surfaces as a message', (
      WidgetTester tester,
    ) async {
      // Uses the real mock repository, which is where the enumerated
      // failures live.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(const _AlwaysTakenAuthRepository()),
            profileRepositoryProvider
                .overrideWithValue(InMemoryProfileRepository()),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'taken@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '5551234567');
      await tester.enterText(find.byType(TextFormField).at(3), 'password1');
      await tester.enterText(find.byType(TextFormField).at(4), 'password1');

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('An account with that email already exists.'),
        findsOneWidget,
      );
    });
  });
}

/// Always rejects signup, so the failure path can be asserted without
/// depending on which addresses the mock happens to treat as taken.
class _AlwaysTakenAuthRepository implements AuthRepository {
  const _AlwaysTakenAuthRepository();

  @override
  Future<AppUser?> currentUser() async => null;

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String genderPreference,
  }) async {
    throw const AuthException(
      AuthFailureKind.emailAlreadyExists,
      'An account with that email already exists.',
    );
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    throw const AuthException(
      AuthFailureKind.invalidCredentials,
      'That email and password combination did not match.',
    );
  }

  @override
  Future<void> signOut() async {}
}
