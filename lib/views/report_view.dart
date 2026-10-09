import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../viewmodels/report_viewmodel.dart';
import '../components/app_circle_button.dart';
import 'camera_overlay_view.dart';
import 'report_onboarding_view.dart';
import '../ui/adaptive/app_page_route.dart';

const _kOnboardingKey = 'report_onboarding_seen';

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_launched) {
      _launched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startReportFlow();
      });
    }
  }

  // ── Onboarding persistence via sqflite ────────────────────────

  Future<Database> _openPrefsDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'app_prefs.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT)',
        );
      },
    );
  }

  Future<bool> _hasSeenOnboarding() async {
    final db = await _openPrefsDb();
    final rows = await db.query(
      'prefs',
      where: 'key = ?',
      whereArgs: [_kOnboardingKey],
    );
    await db.close();
    return rows.isNotEmpty;
  }

  Future<void> _markOnboardingSeen() async {
    final db = await _openPrefsDb();
    await db.insert(
      'prefs',
      {'key': _kOnboardingKey, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.close();
  }

  // ── Flow ──────────────────────────────────────────────────────

  Future<void> _startReportFlow() async {
    final seen = await _hasSeenOnboarding();
    if (!mounted) return;

    if (!seen) {
      final completed = await _showOnboarding();
      if (!mounted) return;
      if (completed != true) {
        // User closed onboarding without finishing — go back
        Navigator.pop(context);
        return;
      }
      await _markOnboardingSeen();
      if (!mounted) return;
    }

    _openCamera();
  }

  Future<bool?> _showOnboarding() {
    return Navigator.push<bool>(
      context,
      appRoute(context, (_) => const ReportOnboardingView()),
    );
  }

  Future<void> _openCamera() async {
    final vm = context.read<ReportViewModel>();
    vm.reset();

    // Open custom camera overlay
    final imagePath = await Navigator.push<String>(
      context,
      appRoute(context, (_) => const CameraOverlayView()),
    );

    if (!mounted) return;

    if (imagePath == null) {
      // User cancelled camera
      Navigator.pop(context);
      return;
    }

    // Process the captured image (verify → OCR → location → station matching)
    final success = await vm.processImage(imagePath);
    if (!mounted) return;

    if (success && vm.step == ReportStep.form) {
      Navigator.pushReplacementNamed(context, '/report-form');
    } else if (!success && vm.errorMessage != null) {
      // Brief delay so user sees the error on the processing screen
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/error');
    } else if (!success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back_ios_new,
                    onPressed: () {
                      context.read<ReportViewModel>().reset();
                      Navigator.pop(context);
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    iconColor: Colors.white,
                  ),
                  const Text(
                    'REPORT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  AppCircleButton(
                    icon: Icons.help_outline,
                    onPressed: () async {
                      await _showOnboarding();
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ReportViewModel>(
                builder: (context, vm, _) {
                  return _buildProcessingUI(vm);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingUI(ReportViewModel vm) {
    final IconData icon;
    final String title;
    final String subtitle;

    switch (vm.step) {
      case ReportStep.idle:
      case ReportStep.capturing:
        icon = Icons.camera_alt_rounded;
        title = 'Opening Camera';
        subtitle = 'Point at the station price board';
      case ReportStep.processing:
        icon = Icons.document_scanner_rounded;
        title = 'Reading Prices';
        subtitle = 'Analyzing the image with OCR...';
      case ReportStep.locating:
        icon = Icons.location_searching_rounded;
        title = 'Getting Location';
        subtitle = 'Finding your current position...';
      case ReportStep.form:
      case ReportStep.submitting:
        icon = Icons.check_circle_rounded;
        title = 'Almost Done';
        subtitle = 'Preparing your report...';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + _pulseController.value * 0.15;
            final opacity = 0.4 + _pulseController.value * 0.6;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFBF94FF)
                      .withValues(alpha: opacity * 0.15),
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBF94FF)
                          .withValues(alpha: opacity * 0.30),
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFBF94FF)),
          ),
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              vm.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
