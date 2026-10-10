import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fuel_insights.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../ui/app_theme.dart';

/// Home card: how far you have driven since filling up and how much is left.
class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fills = context.watch<FillUpViewModel>().fillUps;
    final trips = context.watch<TripViewModel>().history;
    final insights = FuelInsights.compute(fillUps: fills, trips: trips);
    if (insights.lastFillAt == null) return const SizedBox.shrink();

    final fraction = insights.tankUsedFraction;
    final left = insights.estimatedKmLeft;
    final typical = insights.typicalRefillKm;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Since your last fill-up',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatKmShort(insights.kmSinceLastFill ?? 0)} tracked',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (fraction != null && left != null && typical != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F5F9),
                color: fraction > 0.85
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              left > 0
                  ? 'About ${formatKmShort(left)} left at your usual ${formatKmShort(typical)} per tank'
                  : 'Past your usual ${formatKmShort(typical)} per tank — time to fill up',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ] else
            const Text(
              'Log one more fill-up to see how far a tank usually lasts.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          if (insights.costPerKm != null || insights.kmPerLiter != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (insights.costPerKm != null)
                  _Chip(formatCostPerKm(insights.costPerKm)),
                if (insights.kmPerLiter != null)
                  _Chip('${insights.kmPerLiter!.toStringAsFixed(1)} km/L'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}
