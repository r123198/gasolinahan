import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/analytics_charts.dart';
import '../components/analytics_sections.dart';
import '../components/app_empty_state.dart';
import '../models/fuel_analytics.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import 'fill_up_form_sheet.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Fuel analytics: what a month costs at the current pace, how efficient
/// each tank and brand was, spending and price trends, and records.
class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final fillUps = context.watch<FillUpViewModel>().fillUps;
    final a = FuelAnalytics.compute(fillUps, now: DateTime.now());
    return Scaffold(
      appBar: const AppNavBar(title: 'Analytics'),
      body: SafeArea(
        top: false,
        child: a.hasEnoughData
            ? _Report(analytics: a, fillUpCount: fillUps.length)
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
  final int fillUpCount;

  const _Report({required this.analytics, required this.fillUpCount});

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final tanks = a.tanks.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'From $fillUpCount fill-ups · $tanks '
          '${tanks == 1 ? 'tank' : 'tanks'} measured',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _Projection(analytics: a),
        const SizedBox(height: 12),
        _KpiGrid(analytics: a),
        const SizedBox(height: 12),
        if (a.efficiencyTrend.length >= 2) ...[
          AnalyticsSection(
            title: 'Fuel efficiency per tank',
            caption: _routeCaption(a),
            child: TrendLineChart(
              points: a.efficiencyTrend,
              average: a.averageKmPerLiter,
              color: chartIndigo,
              format: (v) => '${v.toStringAsFixed(1)} km/L',
              semanticsSummary: _trendSummary(
                'Fuel efficiency',
                a.efficiencyTrend,
                (v) => '${v.toStringAsFixed(1)} km per liter',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (a.brands.isNotEmpty) ...[
          AnalyticsSection(
            title: 'Brands in your car',
            caption:
                'km per liter on each brand\'s fuel. Same car, so the '
                'difference is the fuel (and the roads you drove).',
            child: BrandRanking(analytics: a),
          ),
          const SizedBox(height: 12),
        ],
        AnalyticsSection(
          title: 'Monthly spending',
          caption: 'Last 6 months. Tap a bar for the amount.',
          child: MonthlySpendChart(months: a.monthlySpend),
        ),
        const SizedBox(height: 12),
        if (a.priceTrend.length >= 2) ...[
          AnalyticsSection(
            title: 'Price you paid per liter',
            caption: 'Every fill-up, oldest to newest.',
            child: TrendLineChart(
              points: a.priceTrend,
              average: a.averagePricePerLiter,
              color: chartCyan,
              format: (v) => '₱${v.toStringAsFixed(2)}',
              semanticsSummary: _trendSummary(
                'Price per liter',
                a.priceTrend,
                (v) => '${v.toStringAsFixed(2)} pesos',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AnalyticsSection(
          title: 'Your records',
          child: RecordsList(analytics: a),
        ),
        const SizedBox(height: 12),
        const _HowWeCalculate(),
      ],
    );
  }

  /// How much tank-to-tank efficiency swings — mostly routes and traffic.
  static String? _routeCaption(FuelAnalytics a) {
    final best = a.bestTank?.kmPerLiter;
    final worst = a.worstTank?.kmPerLiter;
    if (best == null || worst == null || worst <= 0 || best == worst) {
      return 'km per liter for each tank, against your average.';
    }
    final swing = ((best - worst) / worst * 100).round();
    return 'Your best tank went $swing% further than your worst. Highway '
        'driving and light traffic usually explain the good ones.';
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

/// The headline: a month of fuel at the user's current pace.
class _Projection extends StatelessWidget {
  final FuelAnalytics analytics;

  const _Projection({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final monthly = analytics.projectedMonthlyCost;
    final pace = analytics.kmPerDay;
    final cost = analytics.averageCostPerKm;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A month of fuel at your pace',
            style: TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 4),
          Text(
            monthly == null ? '—' : formatPesos(monthly),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFeatures: _tabular,
            ),
          ),
          if (pace != null && cost != null) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${pace.toStringAsFixed(0)} km/day',
                    style: const TextStyle(color: AppColors.onDarkDistance),
                  ),
                  const TextSpan(text: '  ×  30 days  ×  '),
                  TextSpan(
                    text: formatCostPerKm(cost),
                    style: const TextStyle(color: AppColors.onDarkFuel),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onDarkMuted,
                fontFeatures: _tabular,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Log fill-ups on different days to see your pace',
              style: TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final FuelAnalytics analytics;

  const _KpiGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final days = a.averageDaysBetween;
    final km = a.averageKmBetween;
    final tiles = [
      KpiTile(
        label: 'Avg efficiency',
        value: a.averageKmPerLiter == null
            ? '—'
            : '${a.averageKmPerLiter!.toStringAsFixed(1)} km/L',
        color: AppColors.good,
        detail: a.averageKmPerLiter == null ? 'Add liters to fill-ups' : null,
      ),
      KpiTile(
        label: 'Cost per km',
        value: formatCostPerKm(a.averageCostPerKm),
        color: AppColors.distance,
      ),
      KpiTile(
        label: 'Avg price',
        value: a.averagePricePerLiter == null
            ? '—'
            : '${formatPhp(a.averagePricePerLiter!)}/L',
        color: AppColors.fuel,
      ),
      KpiTile(
        label: 'A tank lasts',
        value: days == null ? '—' : '${days.toStringAsFixed(0)} days',
        detail: km == null ? null : '${formatKm(km)} on average',
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 12),
              Expanded(child: tiles[i + 1]),
            ],
          ),
          if (i + 2 < tiles.length) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

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
        child: const ExpansionTile(
          shape: RoundedRectangleBorder(),
          leading: Icon(Icons.help_outline, color: AppColors.textMuted),
          title: Text(
            'How these are calculated',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• Fill up to full each time. The liters you buy replace the '
              'fuel burned since your last fill-up.\n'
              '• km/L = km on the odometer since the last fill-up ÷ liters '
              'bought now.\n'
              '• A tank\'s km/L counts for the brand you filled it with '
              'last time, since that\'s the fuel you burned.\n'
              '• Cost per km = what you paid ÷ km driven.\n'
              '• A month at your pace = km per day × 30 × cost per km.\n'
              '• Routes matter: stop-and-go traffic can cut km/L by a third '
              'compared with open roads, so compare brands over a few tanks.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
