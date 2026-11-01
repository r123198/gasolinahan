import 'package:flutter/material.dart';

import '../models/analytics_period.dart';
import '../models/fuel_analytics.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Amber that reads on ink (7.9:1): "worse" on the dark card.
const _onDarkWarn = Color(0xFFFCD34D);

/// Below this, a change reads as "about the same".
const _sameChangeThreshold = 0.02;

/// Pills that pick the stretch of time the headline sums up.
class RangeChips extends StatelessWidget {
  final AnalyticsRange selected;
  final ValueChanged<AnalyticsRange> onChanged;

  const RangeChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Equal thirds, so the row fits any phone width.
    return Row(
      children: [
        for (final range in AnalyticsRange.values) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: range == selected,
              label: range.label,
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: range == selected ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: range == selected
                        ? AppColors.ink
                        : AppColors.divider,
                  ),
                ),
                child: AppTappable(
                  onTap: () => onChanged(range),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        range.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: range == selected
                              ? Colors.white
                              : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (range != AnalyticsRange.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// The first thing on the Analytics screen: what the stretch cost, how far
/// it went and how efficiently, each against the stretch before it, then
/// a one-line verdict on the latest tank.
class AnalyticsHero extends StatelessWidget {
  final PeriodComparison comparison;
  final FuelAnalytics analytics;

  const AnalyticsHero({
    super.key,
    required this.comparison,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final c = comparison;
    final now = c.current;
    final vs = c.range.comparisonLabel;
    final efficiency = now.kmPerLiter;
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
            _spentLabel(c),
            style: const TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPesosExact(now.spent),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: Colors.white,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
              ),
              if (vs != null) ...[
                const SizedBox(width: 10),
                DeltaTag(change: c.spentChange, higherIsBetter: false),
              ],
            ],
          ),
          Text(
            now.fillUps == 1
                ? '1 fill-up'
                : '${now.fillUps} fill-ups'
                      '${vs != null && c.spentChange != null ? ' · $vs' : ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x33FFFFFF), height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat(
                label: 'Driven',
                value: now.km > 0 ? formatKm(now.km) : '—',
                color: AppColors.onDarkDistance,
                change: vs == null ? null : c.kmChange,
                note: now.km > 0 ? null : 'No full tank measured',
              ),
              _Stat(
                label: 'Efficiency',
                value: efficiency == null
                    ? '—'
                    : '${efficiency.toStringAsFixed(1)} km/L',
                color: AppColors.onDarkGood,
                change: vs == null ? null : c.efficiencyChange,
                higherIsBetter: true,
                note: efficiency == null ? 'Add liters' : null,
              ),
              _Stat(
                label: 'Cost per km',
                value: formatCostPerKm(now.costPerKm),
                color: AppColors.onDarkFuel,
              ),
            ],
          ),
          if (analytics.verdict case final verdict?) ...[
            const SizedBox(height: 14),
            _VerdictStrip(analytics: analytics, verdict: verdict),
          ],
        ],
      ),
    );
  }

  static String _spentLabel(PeriodComparison c) => switch (c.range) {
    AnalyticsRange.month => 'Spent on fuel this month',
    AnalyticsRange.quarter => 'Spent on fuel, last 3 months',
    AnalyticsRange.all => 'Spent on fuel, all time',
  };
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double? change;
  final bool? higherIsBetter;
  final String? note;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.change,
    this.higherIsBetter,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: _tabular,
              ),
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            DeltaTag(change: change, higherIsBetter: higherIsBetter),
          ] else if (note != null)
            Text(
              note!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onDarkMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// "↓ 12%" against the previous stretch, coloured by whether that's good:
/// [higherIsBetter] null means neither (distance), so it stays neutral.
/// Shows "about the same" for tiny changes and nothing without a baseline.
class DeltaTag extends StatelessWidget {
  final double? change;
  final bool? higherIsBetter;

  const DeltaTag({super.key, required this.change, this.higherIsBetter});

  @override
  Widget build(BuildContext context) {
    final change = this.change;
    if (change == null) return const SizedBox.shrink();
    final same = change.abs() < _sameChangeThreshold;
    final up = change > 0;
    final color = same || higherIsBetter == null
        ? AppColors.onDarkMuted
        : (up == higherIsBetter)
        ? AppColors.onDarkGood
        : _onDarkWarn;
    final percent = '${(change.abs() * 100).round()}%';
    final label = same ? 'about the same' : percent;
    return Semantics(
      label: same
          ? 'About the same as before'
          : '$percent ${up ? 'more' : 'less'} than before',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!same)
              Icon(
                up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: color,
              ),
            if (!same) const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Running efficiently / About your usual / Burning more than usual", with
/// the latest tank's km/L against the average.
class _VerdictStrip extends StatelessWidget {
  final FuelAnalytics analytics;
  final EfficiencyVerdict verdict;

  const _VerdictStrip({required this.analytics, required this.verdict});

  @override
  Widget build(BuildContext context) {
    final latest = analytics.latestTank?.kmPerLiter ?? 0;
    final average = analytics.averageKmPerLiter ?? 0;
    final change = analytics.latestEfficiencyChange ?? 0;
    final percent = (change.abs() * 100).round();
    final (title, icon, color) = switch (verdict) {
      EfficiencyVerdict.efficient => (
        'Running efficiently',
        Icons.eco_outlined,
        AppColors.onDarkGood,
      ),
      EfficiencyVerdict.usual => (
        'About your usual',
        Icons.horizontal_rule,
        AppColors.onDarkMuted,
      ),
      EfficiencyVerdict.wasteful => (
        'Burning more than usual',
        Icons.local_fire_department_outlined,
        _onDarkWarn,
      ),
    };
    final detail = switch (verdict) {
      EfficiencyVerdict.usual =>
        'Last tank ${latest.toStringAsFixed(1)} km/L, close to your '
            '${average.toStringAsFixed(1)} average.',
      _ =>
        'Last tank ${latest.toStringAsFixed(1)} km/L, $percent% '
            '${change > 0 ? 'above' : 'below'} your '
            '${average.toStringAsFixed(1)} average.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.onDarkMuted,
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
