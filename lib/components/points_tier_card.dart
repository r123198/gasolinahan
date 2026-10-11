import 'package:flutter/material.dart';

import '../models/points_rules.dart';
import '../ui/app_theme.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Badge colours for the tier icon (decorative; the tier name is the text).
const _tierColors = {
  PointsTier.bronze: Color(0xFFB45309),
  PointsTier.silver: Color(0xFF64748B),
  PointsTier.gold: Color(0xFFCA8A04),
  PointsTier.platinum: Color(0xFF4338CA),
};

/// Tier, balance and how far the next tier is. Keeping the next goal in
/// view (and how to get there) is what keeps people reporting.
class PointsTierCard extends StatelessWidget {
  final int points;
  final int lifetimePoints;

  const PointsTierCard({
    super.key,
    required this.points,
    required this.lifetimePoints,
  });

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(lifetimePoints);
    final toNext = pointsToNextTier(lifetimePoints);
    final next = toNext == null
        ? null
        : PointsTier.values[PointsTier.values.indexOf(tier) + 1];
    final from = tierThresholds[tier]!;
    final to = next == null ? from : tierThresholds[next]!;
    final progress = next == null
        ? 1.0
        : ((lifetimePoints - from) / (to - from)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, size: 32, color: _tierColors[tier]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tier.label} member',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$lifetimePoints points earned',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFeatures: _tabular,
                    ),
                  ),
                  const Text(
                    'to spend',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: next == null
                ? 'Top tier reached'
                : '$toNext points to ${next.label}',
            value: '${(progress * 100).round()}%',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    color: AppColors.distance,
                    backgroundColor: AppColors.surfaceMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  next == null
                      ? const TextSpan(text: 'Top tier reached. Thank you!')
                      : TextSpan(
                          children: [
                            TextSpan(
                              text: '$toNext points',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.distance,
                              ),
                            ),
                            TextSpan(text: ' to ${next.label}'),
                          ],
                        ),
                  style: const TextStyle(fontSize: 13, fontFeatures: _tabular),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _WaysToEarn(),
        ],
      ),
    );
  }
}

class _WaysToEarn extends StatelessWidget {
  const _WaysToEarn();

  @override
  Widget build(BuildContext context) {
    const ways = [
      (
        Icons.photo_camera_outlined,
        'Report a price board',
        '$reportBase–${reportBase + reportMaxProductsCounted * reportPerProduct}',
      ),
      (
        Icons.bolt_outlined,
        'First report after Tuesday\'s price change',
        '+$reportFirstAfterPriceChange',
      ),
      (
        Icons.local_fire_department_outlined,
        'Report every week in a row',
        'up to +$maxWeeklyStreakBonus',
      ),
      (
        Icons.local_gas_station_outlined,
        'Log a fill-up with price and product',
        '${fillUpBase + fillUpCompleteBonus}',
      ),
      (
        Icons.event_repeat_outlined,
        '$monthlyLoggingMinFillUps fill-ups in a month',
        '+$monthlyLoggingPoints',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ways to earn',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        for (final (icon, label, value) in ways)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13)),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.good,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
