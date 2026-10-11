import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_logo.dart';
import '../services/onboarding_prefs.dart';
import '../viewmodels/auth_viewmodel.dart';

const _minSplashTime = Duration(milliseconds: 1200);

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

  /// Auth check, welcome-tour check and a short brand pause run together;
  /// none of them can throw, so the splash never gets stuck.
  Future<void> _navigateToNext() async {
    final authViewModel = context.read<AuthViewModel>();
    final results = await Future.wait<Object?>([
      OnboardingPrefs().checkAndRecordLaunch(DateTime.now()),
      authViewModel.checkAuthState(),
      Future<void>.delayed(_minSplashTime),
    ]);
    final showWelcome = results.first as bool;

    if (!mounted) return;
    final next = authViewModel.isAuthenticated ? '/dashboard' : '/login';
    if (showWelcome) {
      Navigator.pushReplacementNamed(context, '/welcome', arguments: next);
    } else {
      Navigator.pushReplacementNamed(context, next);
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
