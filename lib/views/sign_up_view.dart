import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../components/app_circle_button.dart';
import '../components/app_form_error.dart';
import '../components/app_primary_button.dart';
import '../components/app_text_field.dart';
import '../ui/app_theme.dart';
import '../ui/form_validators.dart';
import 'auth_header.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = validateName(_nameController.text);
      _emailError = validateEmail(_emailController.text);
      _passwordError = validateNewPassword(_passwordController.text);
      _formError = null;
    });
    return _nameError == null && _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    final auth = context.read<AuthViewModel>();
    final success = await auth.signUp(
      _nameController.text.trim(),
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      TextInput.finishAutofillContext();
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
      return;
    }
    setState(() => _formError = auth.errorMessage ?? 'Sign up failed.');
    auth.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthViewModel, bool>((a) => a.isLoading);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppCircleButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back to sign in',
                    onPressed: () => Navigator.maybePop(context),
                    boxShadow: const [],
                  ),
                ),
                const SizedBox(height: 16),
                const AuthHeader(
                  title: 'Create your account',
                  subtitle:
                      'Find the cheapest gas nearby and help others save by '
                      'reporting prices.',
                ),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _nameController,
                  label: 'Name',
                  hint: 'Juan Dela Cruz',
                  icon: Icons.person_outline,
                  errorText: _nameError,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'juan@mail.com',
                  icon: Icons.mail_outline,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least $minPasswordLength characters',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  errorText: _passwordError,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  onToggleObscure: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'By creating an account you agree to our Terms and '
                  'Privacy Policy.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                AppFormError(message: _formError),
                AppPrimaryButton(
                  label: 'Create account',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: 16),
                AuthSwitchPrompt(
                  prompt: 'Already have an account?',
                  action: 'Sign in',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
