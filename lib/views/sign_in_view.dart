import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../components/app_primary_button.dart';
import '../components/app_text_field.dart';
import '../components/app_circle_button.dart';
import '../components/app_social_button.dart';
import '../components/app_divider_with_text.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                    border: Border.all(color: Colors.transparent, width: 2),
                    boxShadow: const [],
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_gas_station,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Gasolinahan',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Locate stations. Compare prices. Report.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 40),
                    AppTextField(
                      controller: _emailController,
                      label: 'EMAIL ADDRESS',
                      hint: 'hello@gasolinahan.com',
                      icon: Icons.mail_outline,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _passwordController,
                      label: 'PASSWORD',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleObscure: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: isCupertino(context)
                          ? AppTextButton(
                              onPressed: () {},
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.zero,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Consumer<AuthViewModel>(
                      builder: (context, authViewModel, child) {
                        return AppPrimaryButton(
                          label: 'Sign In',
                          isLoading: authViewModel.isLoading,
                          trailingIcon: Icons.arrow_forward,
                          borderRadius: 12,
                          onPressed: () async {
                            final success = await authViewModel.signIn(
                              _emailController.text,
                              _passwordController.text,
                            );
                            if (success && context.mounted) {
                              Navigator.pushReplacementNamed(
                                context,
                                '/dashboard',
                              );
                            } else if (!success && context.mounted) {
                              showAppToast(
                                context,
                                authViewModel.errorMessage ?? 'Sign in failed',
                                backgroundColor: Colors.red,
                              );
                              authViewModel.clearError();
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const AppDividerWithText(text: 'OR CONTINUE WITH'),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: AppSocialButton(
                            label: 'Google',
                            icon: Icons.g_mobiledata,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppSocialButton(
                            label: 'Apple',
                            icon: Icons.apple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
