import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/seed_service.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/app_theme.dart';

class SeedView extends StatefulWidget {
  const SeedView({super.key});

  @override
  State<SeedView> createState() => _SeedViewState();
}

class _SeedViewState extends State<SeedView> {
  final SeedService _seedService = SeedService();
  String _log = 'Tap the button to seed the database.';
  bool _isSeeding = false;

  Future<void> _runSeed() async {
    setState(() {
      _isSeeding = true;
      _log = 'Seeding...\n';
    });

    final result = await _seedService.seed();

    setState(() {
      _log = result;
      _isSeeding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppNavBar(
        title: 'Seed Database',
        leading: AppIconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This will create test users and populate Firestore with sample stations, and reports.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            const Text(
              'Test accounts all use password: Test1234!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            _SeedButton(isSeeding: _isSeeding, onPressed: _runSeed),
            const SizedBox(height: 24),
            const Text('Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF4EC9B0),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeedButton extends StatelessWidget {
  final bool isSeeding;
  final VoidCallback onPressed;

  const _SeedButton({required this.isSeeding, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final spinner = const AppSpinner(size: 20, color: Colors.white);

    if (isCupertino(context)) {
      return SizedBox(
        height: 56,
        child: CupertinoButton(
          onPressed: isSeeding ? null : onPressed,
          padding: EdgeInsets.zero,
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          child: isSeeding
              ? spinner
              : const Text(
                  'Seed Database',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: isSeeding ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: isSeeding
          ? spinner
          : const Text(
              'Seed Database',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
