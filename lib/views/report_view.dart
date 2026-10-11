import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../viewmodels/report_viewmodel.dart';
import '../components/app_circle_button.dart';
import 'camera_overlay_view.dart';
import 'report_onboarding_view.dart';
import '../ui/adaptive/app_page_route.dart';
import '../ui/app_theme.dart';

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
    // Respect the system "reduce motion" setting: hold the pulse still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
      _pulseController.value = 1;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
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
    await db.insert('prefs', {
      'key': _kOnboardingKey,
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () {
                      context.read<ReportViewModel>().reset();
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Report prices',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  AppCircleButton(
                    icon: Icons.help_outline,
                    tooltip: 'How reporting works',
                    onPressed: _showOnboarding,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ReportViewModel>(
                builder: (context, vm, _) => _ProcessingSteps(
                  step: vm.step,
                  errorMessage: vm.errorMessage,
                  pulse: _pulseController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scan → read → locate progress, shown while the photo is processed.
class _ProcessingSteps extends StatelessWidget {
  final ReportStep step;
  final String? errorMessage;
  final Animation<double> pulse;

  const _ProcessingSteps({
    required this.step,
    required this.errorMessage,
    required this.pulse,
  });

  static const _steps = [
    (Icons.photo_camera_outlined, 'Take a photo of the price board'),
    (Icons.document_scanner_outlined, 'Read the prices'),
    (Icons.location_on_outlined, 'Find the station you\'re at'),
  ];

  int get _current => switch (step) {
    ReportStep.idle || ReportStep.capturing => 0,
    ReportStep.processing => 1,
    ReportStep.locating => 2,
    ReportStep.form || ReportStep.submitting => 3,
  };

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final (icon, _) = _steps[current.clamp(0, _steps.length - 1)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Center(
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, child) =>
                Transform.scale(scale: 1 + pulse.value * 0.08, child: child),
            child: Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.distance),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          current >= _steps.length ? 'Almost done' : 'Working on your report',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text(
          'This takes a few seconds. Keep the app open.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (final (i, (stepIcon, label)) in _steps.indexed)
                _StepRow(
                  icon: stepIcon,
                  label: label,
                  state: i < current
                      ? _StepState.done
                      : i == current
                      ? _StepState.active
                      : _StepState.waiting,
                ),
            ],
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, active, waiting }

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final _StepState state;

  const _StepRow({
    required this.icon,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final status = switch (state) {
      _StepState.done => 'done',
      _StepState.active => 'in progress',
      _StepState.waiting => 'waiting',
    };
    return Semantics(
      label: '$label, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: switch (state) {
                _StepState.done => const Icon(
                  Icons.check_circle,
                  color: AppColors.good,
                ),
                _StepState.active => const Padding(
                  padding: EdgeInsets.all(4),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.distance,
                  ),
                ),
                _StepState.waiting => Icon(icon, color: AppColors.textMuted),
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: state == _StepState.active
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: state == _StepState.waiting
                      ? AppColors.textMuted
                      : AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
