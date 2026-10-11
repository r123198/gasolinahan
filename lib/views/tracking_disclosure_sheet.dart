import 'package:flutter/material.dart';

import '../components/app_primary_button.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/app_theme.dart';

/// Explains background location and motion use before any system
/// permission prompt (Google Play's "prominent disclosure"). Resolves to
/// true for "Turn on", false for "Not now", and null when dismissed without
/// an answer.
Future<bool?> showTrackingDisclosure(BuildContext context) =>
    showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => const TrackingDisclosure(),
    );

class TrackingDisclosure extends StatelessWidget {
  const TrackingDisclosure({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.route_rounded,
              size: 40,
              color: AppColors.distance,
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'Track your drives automatically?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gasolinahan collects location data to record your drives, '
              'count your kilometers and remind you to log a fill-up at a '
              'gas station, even when the app is closed or not in use.',
              style: TextStyle(fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 16),
            const _Point(
              icon: Icons.directions_car_outlined,
              text:
                  'It also uses physical activity (motion) data to notice '
                  'when you start driving.',
            ),
            const _Point(
              icon: Icons.phone_iphone,
              text: 'Your trips stay on this phone. They are not uploaded.',
            ),
            const _Point(
              icon: Icons.toggle_on_outlined,
              text:
                  'You can turn this off any time in Account → Automatic '
                  'trip tracking.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Next, your phone will ask for location ("Allow all the time" '
              'or "Always") and physical activity access.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Turn on',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 12),
            AppSecondaryButton(
              label: 'Not now',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
