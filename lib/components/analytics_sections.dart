import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../models/fuel_analytics.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';
import 'analytics_charts.dart' show chartIndigo;
import 'brand_logo.dart';

const _tabular = [FontFeature.tabularFigures()];

/// White rounded section with a title and a one-line "what this tells you".
class AnalyticsSection extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget child;

  const AnalyticsSection({
    super.key,
    required this.title,
    required this.child,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Small figure + label, coloured by kind of number.
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final Color color;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.color = AppColors.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: _tabular,
              ),
            ),
          ),
          if (detail != null)
            Text(
              detail!,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Brands ranked by km/L in the user's car: a bar per brand (length =
/// km/L), with ₱/km and how many tanks the number rests on.
class BrandRanking extends StatelessWidget {
  final FuelAnalytics analytics;

  const BrandRanking({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final brands = analytics.brands;
    final best = analytics.bestBrand;
    final top = brands.first.kmPerLiter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (best != null) _Verdict(analytics: analytics, best: best),
        for (final b in brands) ...[
          _BrandRow(
            performance: b,
            fraction: b.kmPerLiter / top,
            isBest: b == best,
          ),
          const SizedBox(height: 14),
        ],
        if (best == null)
          const Text(
            'Log at least 2 tanks of a brand to crown the best one. Mixing '
            'brands shows the difference sooner.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  final FuelAnalytics analytics;
  final BrandPerformance best;

  const _Verdict({required this.analytics, required this.best});

  @override
  Widget build(BuildContext context) {
    final edge = analytics.bestBrandAdvantage;
    final runnerUp = analytics.brands
        .where((b) => b != best)
        .map((b) => b.brand)
        .firstOrNull;
    final message = edge != null && edge > 0.005 && runnerUp != null
        ? '${best.brand} goes ${(edge * 100).toStringAsFixed(0)}% further '
              'per liter than $runnerUp in your car.'
        : '${best.brand} gives you the most km per liter so far.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.good),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  final BrandPerformance performance;
  final double fraction;
  final bool isBest;

  const _BrandRow({
    required this.performance,
    required this.fraction,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    final p = performance;
    final tanks = p.tanks == 1 ? '1 tank' : '${p.tanks} tanks';
    final known = BrandRegistry.findByName(p.brand) != null;
    return Semantics(
      label:
          '${p.brand}: ${p.kmPerLiter.toStringAsFixed(1)} km per liter, '
          '${p.costPerKm.toStringAsFixed(2)} pesos per km, $tanks'
          '${isBest ? ', best' : ''}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 36,
            child: known
                ? brandLogoWidget(p.brand, 32)
                : const Icon(
                    Icons.local_gas_station_outlined,
                    color: AppColors.textMuted,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Best',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.good,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Spacer(),
                    Text(
                      '${p.kmPerLiter.toStringAsFixed(1)} km/L',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.02, 1.0),
                    minHeight: 8,
                    color: chartIndigo,
                    backgroundColor: AppColors.surfaceMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCostPerKm(p.costPerKm)} · '
                  '${p.averagePricePerLiter == null ? '' : '${formatPhp(p.averagePricePerLiter!)}/L avg · '}'
                  '$tanks',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Personal records: longest without refilling, best/worst tank, prices.
class RecordsList extends StatelessWidget {
  final FuelAnalytics analytics;

  const RecordsList({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final gap = a.longestGap;
    final best = a.bestTank;
    final worst = a.worstTank;
    final cheap = a.cheapestPrice;
    final pricey = a.priciestPrice;
    return Column(
      children: [
        if (gap != null)
          _RecordRow(
            icon: Icons.timer_outlined,
            label: 'Longest without refilling',
            value: gap.days == 1 ? '1 day' : '${gap.days} days',
            color: AppColors.distance,
            detail:
                '${formatKm(gap.km)} · ${formatDate(gap.filledAt.timestamp)} '
                'to ${formatDate(gap.measuredAt)}',
          ),
        if (best?.kmPerLiter case final v?)
          _RecordRow(
            icon: Icons.trending_up,
            label: 'Most efficient tank',
            value: '${v.toStringAsFixed(1)} km/L',
            color: AppColors.good,
            detail:
                '${FuelAnalytics.brandOf(best!.filledAt)} · '
                '${formatDate(best.filledAt.timestamp)}',
          ),
        if (worst?.kmPerLiter case final v? when worst != best)
          _RecordRow(
            icon: Icons.trending_down,
            label: 'Least efficient tank',
            value: '${v.toStringAsFixed(1)} km/L',
            color: AppColors.bad,
            detail:
                '${FuelAnalytics.brandOf(worst!.filledAt)} · '
                '${formatDate(worst.filledAt.timestamp)}',
          ),
        if (cheap != null)
          _RecordRow(
            icon: Icons.savings_outlined,
            label: 'Cheapest price paid',
            value: '${formatPhp(cheap.pricePerLiter)}/L',
            color: AppColors.good,
            detail:
                '${cheap.fillUp.stationName} · ${formatDate(cheap.fillUp.timestamp)}',
          ),
        if (pricey != null && pricey != cheap)
          _RecordRow(
            icon: Icons.local_atm_outlined,
            label: 'Highest price paid',
            value: '${formatPhp(pricey.pricePerLiter)}/L',
            color: AppColors.bad,
            detail:
                '${pricey.fillUp.stationName} · '
                '${formatDate(pricey.fillUp.timestamp)}',
          ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _RecordRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}
