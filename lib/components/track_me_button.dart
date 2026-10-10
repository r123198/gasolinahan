import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../views/trip_history_sheet.dart';

const _trackingRed = Color(0xFFDC2626);

/// "Track me" pill for the map. Trips also start on their own when driving is
/// detected, so this mostly shows status; pressing it starts or stops by hand.
/// [onStarted] runs once tracking begins, so the map can follow the user.
class TrackMeButton extends StatelessWidget {
  final VoidCallback? onStarted;

  const TrackMeButton({super.key, this.onStarted});

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
              tooltip: 'Trip history',
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
    if (!context.mounted) return;
    if (vm.permissionDenied) {
      showAppToast(
        context,
        'Allow location (choose "Always") so trips can be tracked.',
      );
      return;
    }
    onStarted?.call();
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
    final foreground = isActive ? Colors.white : AppColors.ink;
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
      child: AppIconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: const EdgeInsets.all(12),
        icon: Icon(icon, size: 22, color: AppColors.ink),
      ),
    );
  }
}
