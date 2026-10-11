import 'package:flutter/material.dart';

import '../models/points_rules.dart';
import '../ui/app_theme.dart';

const _tabular = [FontFeature.tabularFigures()];

/// What a submitted report earned: the total, why, and how close that
/// brings the user to their next tier.
class ReportPointsCard extends StatelessWidget {
  final PointsAward award;
  final bool savedOffline;

  /// Lifetime points before this report, when known.
  final int? lifetimeBefore;

  const ReportPointsCard({
    super.key,
    required this.award,
    required this.savedOffline,
    this.lifetimeBefore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: award.isPending
          ? _Message(
              icon: Icons.hourglass_top_rounded,
              title: 'Points after review',
              body:
                  award.reason ??
                  'These prices look unusual for the area. Once '
                      'they check out, your points arrive.',
            )
          : award.points <= 0
          ? _Message(
              icon: Icons.info_outline,
              title: 'No points this time',
              body: award.reason ?? 'This report did not earn points.',
            )
          : _Earned(
              award: award,
              savedOffline: savedOffline,
              lifetimeBefore: lifetimeBefore,
            ),
    );
  }
}

class _Earned extends StatelessWidget {
  final PointsAward award;
  final bool savedOffline;
  final int? lifetimeBefore;

  const _Earned({
    required this.award,
    required this.savedOffline,
    required this.lifetimeBefore,
  });

  @override
  Widget build(BuildContext context) {
    final before = lifetimeBefore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            '+${award.points} points',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.good,
              fontFeatures: _tabular,
            ),
          ),
        ),
        if (savedOffline)
          const Text(
            'Added when your report syncs.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        const SizedBox(height: 10),
        for (final line in award.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(line.label, style: const TextStyle(fontSize: 14)),
                ),
                Text(
                  '${line.points >= 0 ? '+' : ''}${line.points}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
        if (before != null) ...[
          const SizedBox(height: 12),
          _TierProgress(lifetime: before + award.points),
        ],
      ],
    );
  }
}

/// "14 points to Silver" with a bar from this tier to the next.
class _TierProgress extends StatelessWidget {
  final int lifetime;

  const _TierProgress({required this.lifetime});

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(lifetime);
    final toNext = pointsToNextTier(lifetime);
    if (toNext == null) {
      return Text(
        '${tier.label} tier · $lifetime points',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );
    }
    final start = tierThresholds[tier]!;
    final next = PointsTier.values[tier.index + 1];
    final fraction = (lifetime - start) / (lifetime + toNext - start);
    return Semantics(
      label: '$toNext points to ${next.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$toNext points',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' to ${next.label}'),
              ],
            ),
            style: const TextStyle(fontSize: 14, fontFeatures: _tabular),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.02, 1.0),
              minHeight: 8,
              color: AppColors.ink,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Message({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small "Earn at least N points" line under the report form (streak and
/// first-report bonuses are only known after sending, so it's a floor).
class ReportPointsPreview extends StatelessWidget {
  final PointsAward estimate;

  const ReportPointsPreview({super.key, required this.estimate});

  @override
  Widget build(BuildContext context) {
    final earns = estimate.points > 0 && !estimate.isPending;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            earns ? Icons.stars_rounded : Icons.info_outline,
            size: 18,
            color: earns ? AppColors.good : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              earns
                  ? 'Earn at least ${estimate.points} points'
                  : estimate.reason ?? 'This report won\'t earn points',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: earns ? AppColors.text : AppColors.textMuted,
                fontFeatures: _tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
