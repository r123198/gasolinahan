import 'dart:io';

import 'package:flutter/material.dart';

import '../models/fill_up_log.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';
import 'brand_logo.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Below this, a price difference reads as "about your usual".
const _samePriceThreshold = 0.10;

enum FillUpAction { edit, delete }

/// One fill-up in the Tracker log. The total paid leads; colour then sorts
/// the rest by kind — indigo distance, teal fuel, green/amber for better or
/// worse than the user's own average (always with an arrow and words).
class FillUpLogCard extends StatelessWidget {
  final FillUpLogEntry entry;
  final ValueChanged<FillUpAction> onAction;
  final VoidCallback onStationTap;

  const FillUpLogCard({
    super.key,
    required this.entry,
    required this.onAction,
    required this.onStationTap,
  });

  Future<void> _showMenu(BuildContext context) async {
    final action = await showAppActionSheet<FillUpAction>(
      context: context,
      actions: const [
        AppSheetAction(
          label: 'Edit',
          value: FillUpAction.edit,
          icon: Icons.edit_outlined,
        ),
        AppSheetAction(
          label: 'Delete',
          value: FillUpAction.delete,
          icon: Icons.delete_outline,
          isDestructive: true,
        ),
      ],
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: AppTappable(
        onTap: () => onAction(FillUpAction.edit),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                entry: entry,
                onStationTap: onStationTap,
                onMore: () => _showMenu(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _FuelLine(entry: entry),
                    const SizedBox(height: 12),
                    _StatTiles(entry: entry),
                    _Extras(entry: entry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo, station + fuel grade, date, and the amount paid as the lead number.
class _Header extends StatelessWidget {
  final FillUpLogEntry entry;
  final VoidCallback onStationTap;
  final VoidCallback onMore;

  const _Header({
    required this.entry,
    required this.onStationTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: ExcludeSemantics(
            child: brandLogoWidget(
              fill.brand,
              34,
              stationName: fill.stationName,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Station ${fill.stationName}, show history',
                child: AppTappable(
                  onTap: onStationTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            fill.stationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FuelPill(
                          fuelType: fill.fuelType,
                          productName: fill.productName,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                formatDate(fill.timestamp),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatPesosExact(fill.amountSpent),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ),
        AppIconButton(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
          onPressed: onMore,
        ),
      ],
    );
  }
}

/// Product (or grade) pill in the grade's PH pump colour: "XCS" in
/// Regular blue, "Turbo Diesel" in Diesel green.
class _FuelPill extends StatelessWidget {
  final String fuelType;
  final String? productName;

  const _FuelPill({required this.fuelType, this.productName});

  @override
  Widget build(BuildContext context) {
    final (label, color, tint) = switch (fuelType) {
      'premium' => ('Premium', AppColors.fuelPremium, const Color(0xFFFEE2E2)),
      'diesel' => ('Diesel', AppColors.fuelDiesel, AppColors.goTint),
      _ => ('Regular', AppColors.fuelRegular, const Color(0xFFDBEAFE)),
    };
    final product = productName?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        product.isEmpty ? label : product,
        semanticsLabel: product.isEmpty ? label : '$product, $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// "10.417 L at ₱96.00/L" plus how that price compares with the user's
/// usual for this fuel.
class _FuelLine extends StatelessWidget {
  final FillUpLogEntry entry;

  const _FuelLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    final liters = fill.liters;
    final price = fill.effectivePricePerLiter;
    final delta = entry.priceDelta;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.water_drop,
                    size: 16,
                    color: AppColors.fuel,
                  ),
                ),
              ),
              TextSpan(
                text: liters == null ? 'Liters not set' : formatLiters(liters),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.fuel,
                ),
              ),
              if (price != null)
                TextSpan(
                  text: ' at ${formatPricePerLiter(price)}',
                  style: const TextStyle(color: AppColors.text),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 15, fontFeatures: _tabular),
        ),
        if (delta != null) _PriceVsUsual(delta: delta),
      ],
    );
  }
}

class _PriceVsUsual extends StatelessWidget {
  final double delta;

  const _PriceVsUsual({required this.delta});

  @override
  Widget build(BuildContext context) {
    final same = delta.abs() < _samePriceThreshold;
    final cheaper = delta < 0;
    final color = same
        ? AppColors.textMuted
        : cheaper
        ? AppColors.good
        : AppColors.bad;
    final tint = same
        ? AppColors.surfaceMuted
        : cheaper
        ? AppColors.goTint
        : const Color(0xFFFEF3C7);
    final label = same
        ? 'Your usual price'
        : '₱${delta.abs().toStringAsFixed(2)} '
              '${cheaper ? 'below' : 'above'} usual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!same)
            Icon(
              cheaper ? Icons.arrow_downward : Icons.arrow_upward,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Distance, efficiency and cost per km for the tank before this fill-up.
class _StatTiles extends StatelessWidget {
  final FillUpLogEntry entry;

  const _StatTiles({required this.entry});

  @override
  Widget build(BuildContext context) {
    final km = entry.kmSincePrevious;
    final odometer = Text(
      'Odometer ${formatKm(entry.fillUp.odometerKm)}',
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    );
    if (km == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.insights, size: 20, color: AppColors.distance),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your next fill-up unlocks distance, fuel efficiency '
                    'and cost per km for this tank.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          odometer,
        ],
      );
    }

    final kmPerLiter = entry.kmPerLiter;
    final costPerKm = entry.costPerKm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatTile(
                label: 'Driven',
                value: formatKmDelta(km),
                color: AppColors.distance,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Efficiency',
                value: kmPerLiter == null
                    ? '—'
                    : '${kmPerLiter.toStringAsFixed(2)} km/L',
                trend: kmPerLiter == null
                    ? null
                    : entry.isAboveAverage
                    ? _Trend.better
                    : _Trend.worse,
                note: kmPerLiter == null ? 'Add liters' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Cost',
                value: costPerKm == null ? '—' : formatCostPerKm(costPerKm),
                trend: costPerKm == null
                    ? null
                    : entry.isCheaperPerKm
                    ? _Trend.better
                    : _Trend.worse,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        odometer,
      ],
    );
  }
}

enum _Trend { better, worse }

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final _Trend? trend;
  final String? note;

  const _StatTile({
    required this.label,
    required this.value,
    this.color,
    this.trend,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor =
        color ??
        switch (trend) {
          _Trend.better => AppColors.good,
          _Trend.worse => AppColors.bad,
          null => AppColors.text,
        };
    final caption =
        note ??
        switch (trend) {
          _Trend.better => 'Better than avg',
          _Trend.worse => 'Worse than avg',
          null => null,
        };
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor,
                fontFeatures: _tabular,
              ),
            ),
          ),
          if (caption != null)
            Row(
              children: [
                if (trend != null)
                  Icon(
                    trend == _Trend.better
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 12,
                    color: valueColor,
                  ),
                Flexible(
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trend == null ? AppColors.textMuted : valueColor,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Notes and photos, when the user added them.
class _Extras extends StatelessWidget {
  final FillUpLogEntry entry;

  const _Extras({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    final photos = fill.photoPaths;
    if (fill.notes.isEmpty && photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fill.notes.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fill.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          if (photos.isNotEmpty)
            TextButton.icon(
              onPressed: () => showFillUpPhotos(context, photos),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(
                photos.length == 1 ? '1 photo' : '${photos.length} photos',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

/// Swipeable full-width view of a fill-up's photos.
Future<void> showFillUpPhotos(BuildContext context, List<String> paths) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: PageView(
          children: [
            for (final path in paths)
              InteractiveViewer(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  semanticLabel: 'Fill-up photo',
                  errorBuilder: (_, _, _) => const Center(
                    child: Text(
                      'Photo no longer available',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
