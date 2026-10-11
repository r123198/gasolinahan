import 'package:flutter/material.dart';

import '../components/brand_logo.dart';
import '../components/detour_card.dart';
import '../models/price_freshness.dart';
import '../models/station_model.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Station details: brand, the three pump prices, and — only when this
/// week's Tuesday price change has passed since the last report — a nudge
/// to report the new prices.
Future<void> showStationDetailSheet(
  BuildContext context, {
  required StationModel station,
  required VoidCallback onReport,
  double? userLat,
  double? userLng,
}) {
  return showAppSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(station: station),
            const SizedBox(height: 20),
            _Prices(station: station),
            const SizedBox(height: 12),
            if (pricesMayHaveChanged(station.lastUpdated, DateTime.now()))
              _UpdateNudge(
                reportedAt: station.lastUpdated,
                onReport: () {
                  Navigator.pop(sheetContext);
                  onReport();
                },
              )
            else
              _Current(reportedAt: station.lastUpdated),
            // A station without coordinates (0,0) has no meaningful detour.
            if (userLat != null &&
                userLng != null &&
                (station.latitude != 0 || station.longitude != 0)) ...[
              const SizedBox(height: 12),
              DetourCard(station: station, userLat: userLat, userLng: userLng),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final StationModel station;

  const _Header({required this.station});

  @override
  Widget build(BuildContext context) {
    final subtitle = station.address.isNotEmpty
        ? station.address
        : station.brand;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: ExcludeSemantics(
            child: brandLogoWidget(
              station.brand,
              38,
              stationName: station.name,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  station.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Regular / Premium / Diesel in the colours used on PH pumps.
class _Prices extends StatelessWidget {
  final StationModel station;

  const _Prices({required this.station});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PriceCard(
          label: 'Regular',
          price: station.regularPrice,
          color: AppColors.fuelRegular,
          tint: const Color(0xFFEFF6FF),
        ),
        const SizedBox(width: 8),
        _PriceCard(
          label: 'Premium',
          price: station.premiumPrice,
          color: AppColors.fuelPremium,
          tint: const Color(0xFFFEF2F2),
        ),
        const SizedBox(width: 8),
        _PriceCard(
          label: 'Diesel',
          price: station.dieselPrice,
          color: AppColors.fuelDiesel,
          tint: const Color(0xFFF0FDF4),
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String label;
  final double price;
  final Color color;
  final Color tint;

  const _PriceCard({
    required this.label,
    required this.price,
    required this.color,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final has = price > 0;
    return Expanded(
      child: Semantics(
        label: has
            ? '$label ${price.toStringAsFixed(2)} pesos per liter'
            : '$label price not reported',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  has ? formatPhp(price) : 'No price',
                  style: TextStyle(
                    fontSize: has ? 20 : 14,
                    fontWeight: FontWeight.w700,
                    color: has ? AppColors.text : AppColors.textMuted,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
              if (has)
                const Text(
                  'per liter',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the last report predates this week's Tuesday price change.
class _UpdateNudge extends StatelessWidget {
  final DateTime reportedAt;
  final VoidCallback onReport;

  const _UpdateNudge({required this.reportedAt, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.update, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prices may have changed',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pump prices change every Tuesday. These were reported '
              '${formatDate(reportedAt)}. At this station? Snap the price '
              'board so everyone sees this week\'s prices.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Report new prices'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reassurance that the prices are from this week.
class _Current extends StatelessWidget {
  final DateTime reportedAt;

  const _Current({required this.reportedAt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 16, color: AppColors.good),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'This week\'s prices · reported ${formatRelativeTime(reportedAt)}',
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}
