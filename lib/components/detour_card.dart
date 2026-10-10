import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/detour_advisor.dart';
import '../models/fuel_insights.dart';
import '../models/station_model.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../ui/app_theme.dart';

const _defaultLiters = 15.0;
const _worthGreen = AppColors.goStrong;
const _notWorthAmber = AppColors.warning;

/// "Worth the trip?" — weighs a station's cheaper price against the fuel the
/// extra driving burns, using the user's own cost per km.
class DetourCard extends StatelessWidget {
  final StationModel station;
  final double userLat;
  final double userLng;

  const DetourCard({
    super.key,
    required this.station,
    required this.userLat,
    required this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardViewModel>();
    final insights = FuelInsights.compute(
      fillUps: context.watch<FillUpViewModel>().fillUps,
      trips: context.watch<TripViewModel>().history,
    );
    final costPerKm = insights.costPerKm;
    if (costPerKm == null) return const SizedBox.shrink();

    final advice = adviseDetour(
      userLat: userLat,
      userLng: userLng,
      target: station,
      stations: dashboard.nearbyStations,
      priceOf: (s) => switch (dashboard.fuelType) {
        FuelType.regular => s.regularPrice,
        FuelType.premium => s.premiumPrice,
        FuelType.diesel => s.dieselPrice,
      },
      costPerKm: costPerKm,
      liters: insights.typicalLiters ?? _defaultLiters,
    );
    if (advice == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _body(advice, insights.typicalLiters ?? _defaultLiters),
    );
  }

  Widget _body(DetourAdvice advice, double liters) {
    if (advice.isClosest) {
      return const _Panel(
        color: _worthGreen,
        title: 'Closest station with a price',
        detail: 'No detour needed.',
      );
    }
    final v = advice.verdict;
    final detail =
        '${advice.nearest.name} is closer at '
        '₱${advice.priceHere.toStringAsFixed(2)}/L. '
        'Here saves ~${formatPesos(v.savings)} on ${liters.toStringAsFixed(0)} L, '
        'but ${formatKmShort(advice.extraKm)} extra driving costs '
        '~${formatPesos(v.detourCost)}.';
    return v.worthIt
        ? _Panel(
            color: _worthGreen,
            title: 'Worth the trip: net ~${formatPesos(v.net)} saved',
            detail: detail,
          )
        : _Panel(
            color: _notWorthAmber,
            title: 'Not worth the detour',
            detail: detail,
          );
  }
}

class _Panel extends StatelessWidget {
  final Color color;
  final String title;
  final String detail;

  const _Panel({
    required this.color,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
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
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
