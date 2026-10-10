import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_logo.dart';
import '../viewmodels/auth_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    final authViewModel = context.read<AuthViewModel>();
    await authViewModel.checkAuthState();

    // Brief splash delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (authViewModel.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Matches the native launch screen (white, centered mark) so the hand-off
    // from the OS splash to Flutter is seamless.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: AppLogo(size: 120, showWordmark: true)),
    );
  }
}
