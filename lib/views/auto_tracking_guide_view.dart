import 'package:flutter/material.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/app_theme.dart';

/// One-time setup so the phone opens Gasolinahan whenever it connects to the
/// car. Trips then start on their own once the car moves.
class AutoTrackingGuideView extends StatelessWidget {
  const AutoTrackingGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final isIphone = isCupertino(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Track trips automatically')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            "You don't have to remember to start tracking. Set this up once "
            'and your phone opens Gasolinahan when you get in the car. Trips '
            'then start by themselves as soon as you drive.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          const _Section(
            title: 'First, in the app',
            steps: [
              'Allow location and choose "Always" (iPhone) or "Allow all the time" (Android).',
              'Allow motion & fitness / physical activity when asked.',
              'Leave Gasolinahan installed and do not force-close it.',
            ],
          ),
          _Section(
            title: 'iPhone: CarPlay or car Bluetooth',
            isHighlighted: isIphone,
            steps: const [
              'Open the Shortcuts app and tap Automation, then New Automation.',
              'Choose CarPlay (or Bluetooth, then pick your car).',
              'Select "Is Connected".',
              'Add the action "Open App" and choose Gasolinahan.',
              'Turn on "Run Immediately" and turn off "Notify When Run".',
              'Tap Done.',
            ],
          ),
          _Section(
            title: 'Android: car Bluetooth',
            isHighlighted: !isIphone,
            steps: const [
              'Open Settings, then Modes and Routines (Samsung) or use Google Assistant Routines.',
              'Add a routine with the starter "Bluetooth device connected" and pick your car.',
              'Add the action "Open app" and choose Gasolinahan.',
              'Save it.',
            ],
          ),
          const _Section(
            title: 'Good to know',
            steps: [
              'Tracking only needs the app to be running in the background. If your phone closes it to save battery, the shortcut above reopens it next time you drive.',
              'Your drives stay on your phone. Nothing is uploaded.',
              'Trips under half a kilometre are ignored.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> steps;
  final bool isHighlighted;

  const _Section({
    required this.title,
    required this.steps,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF22C55E)
              : const Color(0xFFF1F5F9),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
