import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9)),
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                    left: BorderSide(color: Color(0xFFF1F5F9)),
                    right: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(
                  Icons.local_gas_station,
                  size: 64,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'GASOLINAHAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
