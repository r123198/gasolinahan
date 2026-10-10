import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../components/app_form_error.dart';
import '../components/app_primary_button.dart';
import '../components/app_text_field.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';
import '../ui/form_validators.dart';
import 'auth_header.dart';

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = validateEmail(_emailController.text);
      _passwordError = validateRequired(
        _passwordController.text,
        'your password',
      );
      _formError = null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    final auth = context.read<AuthViewModel>();
    final success = await auth.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      TextInput.finishAutofillContext();
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
      return;
    }
    setState(() => _formError = auth.errorMessage ?? 'Sign in failed.');
    auth.clearError();
  }

  Future<void> _forgotPassword() async {
    final emailError = validateEmail(_emailController.text);
    if (emailError != null) {
      setState(
        () => _emailError =
            'Enter your email above, then tap '
            '"Forgot password?" again',
      );
      return;
    }
    final error = await context.read<AuthViewModel>().sendPasswordReset(
      _emailController.text,
    );
    if (!mounted) return;
    showAppToast(
      context,
      error ?? 'Reset link sent to ${_emailController.text.trim()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthViewModel, bool>((a) => a.isLoading);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(
                  title: 'Welcome back',
                  subtitle: 'Sign in to compare prices and track your gas.',
                ),
                const SizedBox(height: 32),
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
                  hint: 'Your password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  errorText: _passwordError,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  onToggleObscure: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppTextButton(
                    onPressed: isLoading ? null : _forgotPassword,
                    foregroundColor: AppColors.ink,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppFormError(message: _formError),
                AppPrimaryButton(
                  label: 'Sign in',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: 24),
                AuthSwitchPrompt(
                  prompt: "Don't have an account?",
                  action: 'Create one',
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
