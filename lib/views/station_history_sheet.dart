import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_primary_button.dart';
import '../models/fill_up_model.dart';
import '../models/station_summary.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_format.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import 'fill_up_form_sheet.dart';
import '../ui/app_theme.dart';

/// Fill-up history for one station, with delete and "fill up again".
Future<void> showStationHistory(BuildContext context, StationSummary summary) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StationHistory(stationKey: summary.key),
  );
}

class _StationHistory extends StatelessWidget {
  final String stationKey;
  const _StationHistory({required this.stationKey});

  Future<void> _confirmRemove(
    BuildContext context,
    FillUpViewModel vm,
    FillUp fillUp, {
    required bool isLast,
  }) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete this fill-up?',
      message: isLast
          ? 'This is your only fill-up here, so the station will be removed '
                'from your tracker.'
          : 'It will be removed from your spending totals.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    // Removing the last fill-up removes the station itself; close first so
    // the sheet doesn't sit open with nothing in it.
    if (isLast) Navigator.pop(context);
    await vm.remove(fillUp);
    final error = vm.errorMessage;
    if (error != null && context.mounted) showAppToast(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FillUpViewModel>(
      builder: (context, vm, _) {
        final history = vm.historyFor(stationKey);
        final summary = vm.summaries
            .where((s) => s.key == stationKey)
            .firstOrNull;
        if (summary == null) return const SizedBox(height: 120);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.stationName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.visits} fill-ups · ${formatPesos(summary.totalSpent)} spent',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (_, i) => _HistoryRow(
                      fillUp: history[i],
                      onDelete: () => _confirmRemove(
                        context,
                        vm,
                        history[i],
                        isLast: history.length == 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: 'Fill up here again',
                  trailingIcon: Icons.add_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    showFillUpForm(context, station: summary);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final FillUp fillUp;
  final VoidCallback onDelete;
  const _HistoryRow({required this.fillUp, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final d = fillUp.timestamp;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final liters = fillUp.liters == null
        ? ''
        : ' · ${fillUp.liters!.toStringAsFixed(1)} L';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPhp(fillUp.amountSpent),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${formatKm(fillUp.odometerKm)}$liters',
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
            tooltip: 'Delete fill-up',
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
