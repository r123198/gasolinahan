import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/analytics_charts.dart';
import '../components/analytics_hero.dart';
import '../components/analytics_sections.dart';
import '../components/app_empty_state.dart';
import '../models/analytics_period.dart';
import '../models/fuel_analytics.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import 'fill_up_form_sheet.dart';

const _gap = SizedBox(height: 12);

/// Fuel analytics, top-down: what the chosen stretch cost, how far it went
/// and how efficiently (against the stretch before), then Spending,
/// Driving, Efficiency, Prices and Records in that order.
class AnalyticsView extends StatefulWidget {
  /// Injectable for tests; defaults to the current time.
  final DateTime? now;

  const AnalyticsView({super.key, this.now});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  AnalyticsRange _range = AnalyticsRange.month;

  @override
  Widget build(BuildContext context) {
    final fillUps = context.watch<FillUpViewModel>().fillUps;
    final now = widget.now ?? DateTime.now();
    final a = FuelAnalytics.compute(fillUps, now: now);
    return Scaffold(
      appBar: const AppNavBar(title: 'Analytics'),
      body: SafeArea(
        top: false,
        child: a.hasEnoughData
            ? _Report(
                analytics: a,
                comparison: PeriodComparison.compute(a, _range, now: now),
                onRangeChanged: (r) => setState(() => _range = r),
              )
            : Center(
                child: AppEmptyState(
                  icon: Icons.insights,
                  title: fillUps.isEmpty
                      ? 'No fill-ups yet'
                      : 'One more fill-up to go',
                  subtitle:
                      'Analytics compare one fill-up with the next: km per '
                      'liter, cost per km, which brand goes further in your '
                      'car, and what a month of driving costs.',
                  actionLabel: 'Log a fill-up',
                  onAction: () => showFillUpForm(context),
                ),
              ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final FuelAnalytics analytics;
  final PeriodComparison comparison;
  final ValueChanged<AnalyticsRange> onRangeChanged;

  const _Report({
    required this.analytics,
    required this.comparison,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final tanks = a.tanks.length;
    final drivesAnyKm = a.monthlySpend.any((m) => m.km > 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'From ${a.fillUps.length} fill-ups · $tanks '
          '${tanks == 1 ? 'tank' : 'tanks'} measured',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        _gap,
        RangeChips(selected: comparison.range, onChanged: onRangeChanged),
        _gap,
        AnalyticsHero(comparison: comparison, analytics: a),

        const AnalyticsHeading(
          title: 'Spending',
          subtitle: 'What fuel is costing you',
        ),
        AnalyticsSection(
          title: 'Month by month',
          caption: _spendCaption(a),
          child: MonthlyBarChart(
            months: a.monthlySpend,
            valueOf: (m) => m.spent,
            format: formatPesos,
            axisFormat: compactPesos,
            semanticsName: 'Monthly fuel spending',
          ),
        ),
        _gap,
        _KpiRow(
          tiles: [
            KpiTile(
              label: 'A month of fuel at your pace',
              value: a.projectedMonthlyCost == null
                  ? '—'
                  : formatPesos(a.projectedMonthlyCost!),
              color: AppColors.text,
              detail: a.kmPerDay == null
                  ? 'Log fill-ups on different days'
                  : '${a.kmPerDay!.toStringAsFixed(0)} km/day × '
                        '${formatCostPerKm(a.averageCostPerKm)}',
            ),
            KpiTile(
              label: 'Avg price paid',
              value: a.averagePricePerLiter == null
                  ? '—'
                  : '${formatPhp(a.averagePricePerLiter!)}/L',
              color: AppColors.fuel,
              detail: _priceSpread(a),
            ),
          ],
        ),

        const AnalyticsHeading(
          title: 'Driving',
          subtitle: 'How far your fuel takes you',
        ),
        if (drivesAnyKm) ...[
          AnalyticsSection(
            title: 'Kilometers per month',
            caption: 'Distance covered by the tanks you refilled each month.',
            child: MonthlyBarChart(
              months: a.monthlySpend,
              valueOf: (m) => m.km,
              format: formatKm,
              axisFormat: compactKm,
              semanticsName: 'Kilometers driven per month',
              color: chartCyan,
            ),
          ),
          _gap,
        ],
        _KpiRow(
          tiles: [
            KpiTile(
              label: 'Per day',
              value: a.kmPerDay == null
                  ? '—'
                  : '${a.kmPerDay!.toStringAsFixed(0)} km',
              color: AppColors.distance,
              detail: 'Over the days your fill-ups cover',
            ),
            KpiTile(
              label: 'A tank lasts',
              value: a.averageDaysBetween == null
                  ? '—'
                  : '${a.averageDaysBetween!.toStringAsFixed(0)} days',
              detail: a.averageKmBetween == null
                  ? null
                  : '${formatKm(a.averageKmBetween!)} on average',
            ),
          ],
        ),

        const AnalyticsHeading(
          title: 'Efficiency',
          subtitle: 'How wasteful your car is, tank by tank',
        ),
        if (a.efficiencyTrend.length >= 2) ...[
          AnalyticsSection(
            title: 'Km per liter',
            caption: _routeCaption(a),
            child: TrendLineChart(
              points: a.efficiencyTrend,
              average: a.averageKmPerLiter,
              color: chartGreen,
              format: (v) => '${v.toStringAsFixed(1)} km/L',
              semanticsSummary: _trendSummary(
                'Fuel efficiency',
                a.efficiencyTrend,
                (v) => '${v.toStringAsFixed(1)} km per liter',
              ),
            ),
          ),
          _gap,
        ] else
          const _Hint(
            'Add liters to at least two fill-ups to see your km per liter '
            'tank by tank.',
          ),
        _KpiRow(
          tiles: [
            KpiTile(
              label: 'Avg efficiency',
              value: a.averageKmPerLiter == null
                  ? '—'
                  : '${a.averageKmPerLiter!.toStringAsFixed(1)} km/L',
              color: AppColors.good,
              detail: _bestWorst(a),
            ),
            KpiTile(
              label: 'Cost per km',
              value: formatCostPerKm(a.averageCostPerKm),
              color: AppColors.distance,
              detail: 'Everything you paid ÷ km driven',
            ),
          ],
        ),
        if (a.brands.isNotEmpty) ...[
          _gap,
          AnalyticsSection(
            title: 'Brands in your car',
            caption:
                'km per liter on each brand\'s fuel. Same car, so the '
                'difference is the fuel (and the roads you drove).',
            child: BrandRanking(analytics: a),
          ),
        ],

        if (a.priceTrend.length >= 2) ...[
          const AnalyticsHeading(
            title: 'Prices',
            subtitle: 'What you paid per liter, fill-up by fill-up',
          ),
          AnalyticsSection(
            title: 'Price per liter',
            caption: 'Every fill-up, oldest to newest, against your average.',
            child: TrendLineChart(
              points: a.priceTrend,
              average: a.averagePricePerLiter,
              color: chartIndigo,
              format: (v) => '₱${v.toStringAsFixed(2)}',
              semanticsSummary: _trendSummary(
                'Price per liter',
                a.priceTrend,
                (v) => '${v.toStringAsFixed(2)} pesos',
              ),
            ),
          ),
        ],

        const AnalyticsHeading(title: 'Records'),
        AnalyticsSection(
          title: 'Your personal bests and worsts',
          child: RecordsList(analytics: a),
        ),
        _gap,
        const _HowWeCalculate(),
      ],
    );
  }

  /// This month against last, in words, under the spending chart.
  static String? _spendCaption(FuelAnalytics a) {
    final months = a.monthlySpend;
    if (months.length < 2) return null;
    final now = months.last;
    final before = months[months.length - 2];
    final nowName = shortMonth(now.month);
    final beforeName = shortMonth(before.month);
    if (before.spent <= 0) {
      return now.spent > 0
          ? '$nowName so far: ${formatPesos(now.spent)}. Nothing logged in '
                '$beforeName.'
          : 'Nothing logged yet in $beforeName or $nowName.';
    }
    final change = (now.spent - before.spent) / before.spent;
    final percent = (change.abs() * 100).round();
    final direction = change < 0 ? 'less' : 'more';
    return '$nowName ${formatPesos(now.spent)} vs $beforeName '
        '${formatPesos(before.spent)}: $percent% $direction so far.';
  }

  static String? _priceSpread(FuelAnalytics a) {
    final cheap = a.cheapestPrice;
    final pricey = a.priciestPrice;
    if (cheap == null || pricey == null) return null;
    return '${formatPhp(cheap.pricePerLiter)} to '
        '${formatPhp(pricey.pricePerLiter)}';
  }

  static String? _bestWorst(FuelAnalytics a) {
    final best = a.bestTank?.kmPerLiter;
    final worst = a.worstTank?.kmPerLiter;
    if (best == null || worst == null) return null;
    return 'Best ${best.toStringAsFixed(1)} · worst ${worst.toStringAsFixed(1)}';
  }

  /// How much tank-to-tank efficiency swings — mostly routes and traffic.
  static String? _routeCaption(FuelAnalytics a) {
    final best = a.bestTank?.kmPerLiter;
    final worst = a.worstTank?.kmPerLiter;
    if (best == null || worst == null || worst <= 0 || best == worst) {
      return 'Each tank against your average: above the line is better.';
    }
    final swing = ((best - worst) / worst * 100).round();
    return 'Above the dashed line beats your average. Your best tank went '
        '$swing% further than your worst; highway driving and light traffic '
        'usually explain the good ones.';
  }

  static String _trendSummary(
    String name,
    List<TrendPoint> points,
    String Function(double) say,
  ) {
    final first = points.first;
    final last = points.last;
    return '$name from ${formatDate(first.date)} to ${formatDate(last.date)}: '
        'started at ${say(first.value)}, latest ${say(last.value)}.';
  }
}

class _KpiRow extends StatelessWidget {
  final List<KpiTile> tiles;

  const _KpiRow({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, tile) in tiles.indexed) ...[
          Expanded(child: tile),
          if (i < tiles.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }
}

/// One rule in [_HowWeCalculate]: a bold name, the formula on its own
/// line (when there is one), and a plain-words note.
class _Rule {
  final String name;
  final String? formula;
  final String note;
  const _Rule(this.name, {this.formula, required this.note});
}

const _rules = [
  _Rule(
    'Fill up to full each time',
    note:
        'The liters you buy replace the fuel burned since your last '
        'fill-up, so every tank can be measured.',
  ),
  _Rule(
    'Km per liter',
    formula: 'km since last fill-up ÷ liters bought now',
    note:
        'A tank counts for the brand you filled it with last time, since '
        'that is the fuel you burned.',
  ),
  _Rule(
    'Cost per km',
    formula: 'amount paid ÷ km driven on that tank',
    note: 'What each kilometer costs you at the price you paid.',
  ),
  _Rule(
    'A month at your pace',
    formula: 'km per day × 30 × cost per km',
    note: 'What a typical month of driving costs in fuel.',
  ),
  _Rule(
    'This month',
    note:
        'Fill-ups dated this month, plus the distance of tanks refilled '
        'this month, compared with last month.',
  ),
  _Rule(
    'Routes matter',
    note:
        'Stop-and-go traffic can cut km/L by a third compared with open '
        'roads, so compare brands over a few tanks.',
  ),
];

class _HowWeCalculate extends StatelessWidget {
  const _HowWeCalculate();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(),
          leading: const Icon(Icons.help_outline, color: AppColors.textMuted),
          title: const Text(
            'How these are calculated',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final r in _rules) _RuleTile(rule: r)],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final _Rule rule;
  const _RuleTile({required this.rule});

  @override
  Widget build(BuildContext context) {
    final formula = rule.formula;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rule.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (formula != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '= $formula',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.distance,
                  height: 1.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            rule.note,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
