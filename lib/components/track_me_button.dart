import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../views/trip_history_sheet.dart';

const _trackingRed = Color(0xFFDC2626);

/// "Track me" pill for the map. Trips also start on their own when driving is
/// detected, so this mostly shows status; pressing it starts or stops by hand.
class TrackMeButton extends StatelessWidget {
  const TrackMeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripViewModel>(
      builder: (context, vm, _) {
        return Row(
          children: [
            _Pill(
              isActive: vm.isTracking,
              label: vm.isTracking
                  ? 'Tracking · ${formatKmShort(vm.liveDistanceKm)} · Stop'
                  : 'Track me',
              icon: vm.isTracking
                  ? Icons.stop_circle_rounded
                  : Icons.navigation_rounded,
              onTap: () => _toggle(context, vm),
            ),
            const SizedBox(width: 8),
            _RoundIcon(
              icon: Icons.history_rounded,
              onTap: () => showTripHistory(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, TripViewModel vm) async {
    if (vm.isTracking) {
      await vm.stopNow();
      return;
    }
    await vm.trackNow();
    if (vm.permissionDenied && context.mounted) {
      showAppToast(
        context,
        'Allow location (choose "Always") so trips can be tracked.',
      );
    }
  }
}

class _Pill extends StatelessWidget {
  final bool isActive;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Pill({
    required this.isActive,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? Colors.white : const Color(0xFF111827);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? _trackingRed : Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: const Color(0xFF111827)),
        ),
      ),
    );
  }
}
