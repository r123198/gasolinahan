import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/fuel_analytics.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';

/// Chart mark colours. Validated with the dataviz palette checks (lightness,
/// chroma, colour-blind separation, ≥3:1 on white).
const chartIndigo = Color(0xFF4338CA);
const chartCyan = Color(0xFF0891B2);
const _grid = Color(0xFFE2E8F0);
const _chartHeight = 180.0;
const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortDate(DateTime d) => '${_shortMonths[d.month - 1]} ${d.day}';

const _axisStyle = TextStyle(fontSize: 11, color: AppColors.textMuted);
const _tooltipStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

/// One measure over time as a 2px line with dots, plus a dashed line at
/// the user's average. Tap a dot to read its value.
class TrendLineChart extends StatelessWidget {
  final List<TrendPoint> points;
  final double? average;
  final Color color;
  final String Function(double) format;
  final String semanticsSummary;

  const TrendLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    required this.semanticsSummary,
    this.average,
  });

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value).toList();
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final pad = ((high - low) * 0.2).clamp(0.5, double.infinity);
    final labelEvery = (points.length / 4).ceil().clamp(1, points.length);
    return Semantics(
      label: semanticsSummary,
      excludeSemantics: true,
      child: SizedBox(
        height: _chartHeight,
        child: LineChart(
          LineChartData(
            minY: (low - pad).floorToDouble().clamp(0, double.infinity),
            maxY: (high + pad).ceilToDouble(),
            minX: 0,
            maxX: (points.length - 1).toDouble().clamp(1, double.infinity),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: _grid, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(meta.formattedValue, style: _axisStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= points.length || i % labelEvery != 0) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _shortDate(points[i].date),
                        style: _axisStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (average != null)
                  HorizontalLine(
                    y: average!,
                    color: AppColors.textMuted,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: _axisStyle,
                      labelResolver: (_) => 'avg ${format(average!)}',
                    ),
                  ),
              ],
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${format(s.y)}\n${_shortDate(points[s.x.round()].date)}',
                      _tooltipStyle,
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (i, p) in points.indexed)
                    FlSpot(i.toDouble(), p.value),
                ],
                color: color,
                barWidth: 2,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spending per month as columns, current month last.
class MonthlySpendChart extends StatelessWidget {
  final List<MonthSpend> months;

  const MonthlySpendChart({super.key, required this.months});

  @override
  Widget build(BuildContext context) {
    final high = months.map((m) => m.spent).fold(0.0, (a, b) => a > b ? a : b);
    final summary = months
        .map(
          (m) => '${_shortMonths[m.month.month - 1]} ${formatPesos(m.spent)}',
        )
        .join(', ');
    return Semantics(
      label: 'Monthly fuel spending: $summary',
      excludeSemantics: true,
      child: SizedBox(
        height: _chartHeight,
        child: BarChart(
          BarChartData(
            maxY: high <= 0 ? 1000 : high * 1.2,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: _grid, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(_compactPesos(value), style: _axisStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _shortMonths[months[value.round()].month.month - 1],
                      style: _axisStyle,
                    ),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItem: (group, _, rod, _) =>
                    BarTooltipItem(formatPesos(rod.toY), _tooltipStyle),
              ),
            ),
            barGroups: [
              for (final (i, m) in months.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: m.spent,
                      color: chartIndigo,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _compactPesos(double v) => v >= 1000
      ? '₱${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
      : '₱${v.round()}';
}
