import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_primary_button.dart';
import '../models/fill_up_model.dart';
import '../models/station_summary.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/app_format.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import 'fill_up_form_sheet.dart';

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
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.visits} fill-ups · ${formatPesos(summary.totalSpent)} spent',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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
                      onDelete: () => vm.remove(history[i]),
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
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final liters = fillUp.liters == null ? '' : ' · ${fillUp.liters!.toStringAsFixed(1)} L';
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${formatKm(fillUp.odometerKm)}$liters',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete fill-up',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
