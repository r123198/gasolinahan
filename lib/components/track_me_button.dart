import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../views/trip_history_sheet.dart';

/// Stop icon on the black "tracking" pill (6.0:1 on ink).
const _recordingRed = Color(0xFFF87171);

/// "Track me" pill for the map. Trips also start on their own when driving is
/// detected, so this mostly shows status; pressing it starts or stops by hand.
/// [onStarted] runs once tracking begins, so the map can follow the user;
/// [onStopped] runs once it is stopped by hand, so the map can stop following.
class TrackMeButton extends StatelessWidget {
  final VoidCallback? onStarted;
  final VoidCallback? onStopped;

  const TrackMeButton({super.key, this.onStarted, this.onStopped});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripViewModel>(
      builder: (context, vm, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shrinks (label ends in "…") instead of pushing the history
            // button off-screen when the live label is long.
            Flexible(
              child: _Pill(
                isActive: vm.isTracking,
                label: vm.isTracking
                    ? 'Tracking · ${formatKmShort(vm.liveDistanceKm)} · Stop'
                    : 'Track me',
                icon: vm.isTracking
                    ? Icons.stop_circle_rounded
                    : Icons.navigation_rounded,
                onTap: () => _toggle(context, vm),
              ),
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
      try {
        await vm.stopNow();
      } on Exception catch (e) {
        debugPrint('Stop tracking failed: $e');
      }
      onStopped?.call();
      return;
    }
    final agreed = await showAppConfirmDialog(
      context: context,
      title: 'Track this trip?',
      message:
          'Gasolinahan will use your location for the whole trip — even '
          'with the app in the background or your screen off — to measure '
          'how far you drive and what it costs.\n\n'
          'Your route stays on this phone. Tap Stop whenever you want to '
          'end tracking.',
      confirmLabel: 'Start tracking',
      cancelLabel: 'Not now',
    );
    if (!agreed || !context.mounted) return;
    try {
      await vm.trackNow();
    } on Exception catch (e) {
      debugPrint('Track me failed: $e');
    }
    if (!context.mounted) return;
    if (vm.permissionDenied) {
      showAppToast(
        context,
        'Allow location (choose "Always") so trips can be tracked.',
      );
      return;
    }
    if (!vm.isTracking) {
      showAppToast(context, "Couldn't start tracking. Please try again.");
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
        color: isActive ? AppColors.ink : Colors.white,
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
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? _recordingRed : foreground,
                ),
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
