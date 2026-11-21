import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/widgets/common.dart';
import '../../providers/providers.dart';
import '../../repositories/auth_repository.dart';

/// Signup.
///
/// Authentication is mocked, but validation and failure handling are real:
/// the point of the mock's enumerated failure modes is that this screen can
/// be built and tested against them. Try `taken@example.com` for a duplicate
/// and any address containing "network" for a transport failure.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String _clothingPreference = 'Menswear';
  bool _obscurePassword = true;
  bool _submitting = false;

  static const List<String> _preferences = <String>[
    'Menswear',
    'Womenswear',
    'Both',
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'That name looks too short';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    // Deliberately permissive: the goal is to catch typos, not to reimplement
    // RFC 5322.
    final RegExp pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!pattern.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter at least 10 digits';
    if (digits.length > 15) return 'That is too many digits';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'Include at least one letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) return 'Include at least one number';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != _password.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).signUp(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            genderPreference: _clothingPreference,
          );
      if (!mounted) return;
      context.go(Routes.onboarding);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: <Widget>[
              Text(
                'Create your account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A few details so recommendations fit you.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              LabeledField(
                label: 'Name',
                child: TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Your name'),
                  validator: _validateName,
                ),
              ),

              LabeledField(
                label: 'Clothing preference',
                child: ChipSingleSelect(
                  options: _preferences,
                  selected: _clothingPreference,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _clothingPreference = value);
                    }
                  },
                ),
              ),

              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration:
                      const InputDecoration(hintText: 'you@example.com'),
                  validator: _validateEmail,
                ),
              ),

              LabeledField(
                label: 'Phone',
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '555 123 4567'),
                  validator: _validatePhone,
                ),
              ),

              LabeledField(
                label: 'Password',
                child: TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'At least 8 characters',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                  validator: _validatePassword,
                ),
              ),

              LabeledField(
                label: 'Confirm password',
                child: TextFormField(
                  controller: _confirm,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Re-enter your password',
                  ),
                  validator: _validateConfirm,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),

              const SizedBox(height: 8),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),

              const SizedBox(height: 20),
              Text(
                'Accounts are stored on this device only. This prototype has '
                'no server.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
