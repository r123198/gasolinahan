import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auto_tracking_guide_view.dart';
import '../models/fuel_insights.dart';
import '../models/trip_model.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../ui/app_theme.dart';

Future<void> showTripHistory(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TripHistory(),
  );
}

class _TripHistory extends StatelessWidget {
  const _TripHistory();

  Future<void> _confirmDelete(
    BuildContext context,
    TripViewModel vm,
    Trip trip,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete this trip?',
      message: 'Its distance will be removed from your totals.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await vm.deleteTrip(trip);
    // errorMessage may be left over from tracking, so check the list itself.
    final stillThere = vm.history.any((t) => t.id == trip.id);
    if (stillThere && context.mounted) {
      showAppToast(context, "Couldn't delete this trip. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripViewModel>(
      builder: (context, vm, _) {
        final trips = vm.history;
        final totalKm = trips.fold(0.0, (sum, t) => sum + t.distanceKm);
        final costPerKm = FuelInsights.compute(
          fillUps: context.watch<FillUpViewModel>().fillUps,
          trips: trips,
        ).costPerKm;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your trips',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trips.isEmpty
                      ? 'Trips are recorded automatically when you drive.'
                      : '${trips.length} trips · ${formatKmShort(totalKm)} tracked',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AutoTrackingGuideView(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.directions_car_filled_outlined,
                    size: 18,
                  ),
                  label: const Text('Start tracking automatically in my car'),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: trips.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (_, i) => _TripRow(
                      trip: trips[i],
                      costPerKm: costPerKm,
                      onDelete: () => _confirmDelete(context, vm, trips[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripRow extends StatelessWidget {
  final Trip trip;
  final double? costPerKm;
  final VoidCallback onDelete;
  const _TripRow({
    required this.trip,
    required this.costPerKm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d = trip.startedAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  costPerKm == null
                      ? formatKmShort(trip.distanceKm)
                      : '${formatKmShort(trip.distanceKm)} · ~${formatPesos(trip.distanceKm * costPerKm!)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date $time · ${formatDuration(trip.duration)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete trip',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
