import 'package:flutter/material.dart';

import '../models/fill_up_log.dart';
import '../models/station_summary.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';

const _tabular = [FontFeature.tabularFigures()];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Dark headline card on the Tracker tab: this month's spend leads, then
/// the user's averages, each coloured by kind (fuel price teal, efficiency
/// green, distance indigo).
class TrackerSummaryCard extends StatelessWidget {
  final FillUpLog log;
  final TrackerTotals totals;
  final DateTime now;
  final VoidCallback onOpenAnalytics;

  const TrackerSummaryCard({
    super.key,
    required this.log,
    required this.totals,
    required this.now,
    required this.onOpenAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final month = log.monthSummary(now);
    final price = log.averagePricePerLiter;
    final efficiency = log.averageKmPerLiter;
    final costPerKm = totals.costPerKm;
    const waiting = 'After 2 fill-ups';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spent in ${_months[now.month - 1]}',
            style: const TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatPesosExact(month.spent),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  fontFeatures: _tabular,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                month.fillUps == 1 ? '1 fill-up' : '${month.fillUps} fill-ups',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onDarkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x33FFFFFF)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat(
                label: 'Avg price',
                value: price == null ? '—' : '${formatPhp(price)}/L',
                color: AppColors.onDarkFuel,
              ),
              _Stat(
                label: 'Efficiency',
                value: efficiency == null
                    ? waiting
                    : '${efficiency.toStringAsFixed(1)} km/L',
                color: efficiency == null
                    ? AppColors.onDarkMuted
                    : AppColors.onDarkGood,
              ),
              _Stat(
                label: 'Cost per km',
                value: costPerKm == null ? waiting : formatCostPerKm(costPerKm),
                color: costPerKm == null
                    ? AppColors.onDarkMuted
                    : AppColors.onDarkDistance,
              ),
            ],
          ),
          if (totals.totalKm > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${formatKm(totals.totalKm)} logged in total · '
              '${formatPesos(totals.totalSpent)} spent',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onDarkMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onOpenAnalytics,
              icon: const Icon(Icons.insights, size: 18),
              label: const Text('See full analytics'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x66FFFFFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = color == AppColors.onDarkMuted;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            style: TextStyle(
              fontSize: isPlaceholder ? 12 : 16,
              fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w700,
              color: color,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}
