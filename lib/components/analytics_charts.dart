import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/fuel_analytics.dart';
import '../ui/app_theme.dart';

/// Chart mark colours. Validated with the dataviz palette checks (lightness,
/// chroma, colour-blind separation, ≥3:1 on white).
const chartIndigo = Color(0xFF4338CA);
const chartCyan = Color(0xFF0891B2);
const chartGreen = Color(0xFF15803D);

/// Bars that aren't the one being talked about.
const _barMuted = Color(0xFFC7D2FE);
const _grid = Color(0xFFE2E8F0);
const _chartHeight = 190.0;
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

String shortMonth(DateTime d) => _shortMonths[d.month - 1];
String _shortDate(DateTime d) => '${shortMonth(d)} ${d.day}';

const _axisStyle = TextStyle(fontSize: 11, color: AppColors.textMuted);
const _tooltipStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

/// One measure over time: a line with a soft fill, dots for each reading,
/// the latest one called out with its value, and a dashed line at the
/// user's average so every point reads as above or below it.
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
    final pad = ((high - low) * 0.25).clamp(0.5, double.infinity);
    final labelEvery = (points.length / 4).ceil().clamp(1, points.length);
    final last = points.length - 1;
    final line = LineChartBarData(
      spots: [
        for (final (i, p) in points.indexed) FlSpot(i.toDouble(), p.value),
      ],
      color: color,
      barWidth: 2.5,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ),
      ),
      dotData: FlDotData(
        getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
          radius: index == last ? 5.5 : 3.5,
          color: index == last ? color : Colors.white,
          strokeWidth: 2,
          strokeColor: color,
        ),
      ),
    );
    return Semantics(
      label: semanticsSummary,
      excludeSemantics: true,
      child: SizedBox(
        height: _chartHeight,
        child: LineChart(
          LineChartData(
            minY: (low - pad).floorToDouble().clamp(0, double.infinity),
            // Headroom for the latest value's label.
            maxY: (high + pad * 1.6).ceilToDouble(),
            minX: 0,
            maxX: last.toDouble().clamp(1, double.infinity),
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
                      alignment: Alignment.topLeft,
                      style: _axisStyle,
                      labelResolver: (_) => 'your avg ${format(average!)}',
                    ),
                  ),
              ],
            ),
            // The latest reading is labelled without a tap.
            showingTooltipIndicators: [
              ShowingTooltipIndicators([
                LineBarSpot(line, 0, line.spots[last]),
              ]),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${format(s.y)}\n${_shortDate(points[s.x.round()].date)}',
                      _tooltipStyle,
                    ),
                ],
              ),
            ),
            lineBarsData: [line],
          ),
        ),
      ),
    );
  }
}

/// One number per month as columns, oldest to newest. The current month is
/// drawn in full colour with its value above it; earlier months are muted,
/// so the eye lands on "now" and reads the rest as context. Tap any bar
/// for its value.
class MonthlyBarChart extends StatelessWidget {
  final List<MonthSpend> months;
  final double Function(MonthSpend) valueOf;

  /// Full value, for the bar label and tooltip.
  final String Function(double) format;

  /// Short value for the axis, e.g. "₱2.5k" or "300".
  final String Function(double) axisFormat;
  final Color color;

  /// Read out by screen readers, e.g. "Monthly fuel spending".
  final String semanticsName;

  const MonthlyBarChart({
    super.key,
    required this.months,
    required this.valueOf,
    required this.format,
    required this.axisFormat,
    required this.semanticsName,
    this.color = chartIndigo,
  });

  @override
  Widget build(BuildContext context) {
    final values = months.map(valueOf).toList();
    final high = values.fold(0.0, (a, b) => a > b ? a : b);
    final last = months.length - 1;
    final summary = [
      for (final (i, m) in months.indexed)
        '${shortMonth(m.month)} ${format(values[i])}',
    ].join(', ');
    return Semantics(
      label: '$semanticsName: $summary',
      excludeSemantics: true,
      child: SizedBox(
        height: _chartHeight,
        child: BarChart(
          BarChartData(
            maxY: high <= 0 ? 1 : high * 1.3,
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
                    child: Text(axisFormat(value), style: _axisStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        shortMonth(months[i].month),
                        style: i == last
                            ? _axisStyle.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              )
                            : _axisStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                tooltipMargin: 6,
                getTooltipItem: (group, _, rod, _) =>
                    BarTooltipItem(format(rod.toY), _tooltipStyle),
              ),
            ),
            barGroups: [
              for (final (i, v) in values.indexed)
                BarChartGroupData(
                  x: i,
                  // The current month's value is always visible.
                  showingTooltipIndicators: i == last && v > 0 ? [0] : [],
                  barRods: [
                    BarChartRodData(
                      toY: v,
                      color: i == last ? color : _barMuted,
                      width: 22,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
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
}

String compactPesos(double v) => v >= 1000
    ? '₱${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
    : '₱${v.round()}';

String compactKm(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.round().toString();
