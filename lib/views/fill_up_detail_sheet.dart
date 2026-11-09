import 'package:flutter/material.dart';

import '../components/app_primary_button.dart';
import '../components/brand_logo.dart';
import '../components/fill_up_log_card.dart'
    show FillUpAction, showFillUpPhotos;
import '../components/fuel_pill.dart';
import '../models/fill_up_log.dart';
import '../ui/device_photo.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Below this, a price difference reads as "about your usual".
const _samePriceThreshold = 0.10;
const _thumbSize = 72.0;

/// Everything about one fill-up, read-only, with Edit and Delete at the
/// bottom. Returns the action the user chose, or null if they just closed
/// it.
Future<FillUpAction?> showFillUpDetail(
  BuildContext context,
  FillUpLogEntry entry,
) {
  return showAppSheet<FillUpAction>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FillUpDetailSheet(entry: entry),
  );
}

class FillUpDetailSheet extends StatelessWidget {
  final FillUpLogEntry entry;

  const FillUpDetailSheet({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(entry: entry),
                    const SizedBox(height: 16),
                    _Amount(entry: entry),
                    const SizedBox(height: 16),
                    _TankStats(entry: entry),
                    if (fill.notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Notes(notes: fill.notes),
                    ],
                    if (fill.photoPaths.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Photos(paths: fill.photoPaths),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                children: [
                  AppPrimaryButton(
                    label: 'Edit fill-up',
                    trailingIcon: Icons.edit_outlined,
                    height: 52,
                    onPressed: () => Navigator.pop(context, FillUpAction.edit),
                  ),
                  const SizedBox(height: 4),
                  AppTextButton(
                    onPressed: () =>
                        Navigator.pop(context, FillUpAction.delete),
                    child: const Text(
                      'Delete fill-up',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FillUpLogEntry entry;

  const _Header({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
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
                header: true,
                child: Text(
                  fill.stationName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FuelGradePill(
                    fuelType: fill.fuelType,
                    productName: fill.productName,
                  ),
                  Text(
                    formatDate(fill.timestamp),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppIconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// What was paid, for how many liters, at what price — and how that price
/// compares with the user's usual.
class _Amount extends StatelessWidget {
  final FillUpLogEntry entry;

  const _Amount({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    final liters = fill.liters;
    final price = fill.effectivePricePerLiter;
    final delta = entry.priceDelta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paid',
            style: TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
          ),
          Text(
            formatPesosExact(fill.amountSpent),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Colors.white,
              fontFeatures: _tabular,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: liters == null
                      ? 'Liters not set'
                      : formatLiters(liters),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onDarkFuel,
                  ),
                ),
                if (price != null)
                  TextSpan(text: ' at ${formatPricePerLiter(price)}'),
              ],
            ),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontFeatures: _tabular,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(
              _priceVsUsual(delta),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: delta.abs() < _samePriceThreshold
                    ? AppColors.onDarkMuted
                    : delta < 0
                    ? AppColors.onDarkGood
                    : const Color(0xFFFCD34D),
                fontFeatures: _tabular,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _priceVsUsual(double delta) {
    if (delta.abs() < _samePriceThreshold) return 'Your usual price';
    final diff = '₱${delta.abs().toStringAsFixed(2)}/L';
    return delta < 0 ? '$diff below your usual' : '$diff above your usual';
  }
}

/// Odometer, distance, efficiency and cost per km for the tank before this
/// fill-up, each against the user's own average.
class _TankStats extends StatelessWidget {
  final FillUpLogEntry entry;

  const _TankStats({required this.entry});

  @override
  Widget build(BuildContext context) {
    final km = entry.kmSincePrevious;
    final kmPerLiter = entry.kmPerLiter;
    final costPerKm = entry.costPerKm;
    final tiles = [
      _Tile(
        label: 'Odometer',
        value: formatKm(entry.fillUp.odometerKm),
        color: AppColors.text,
      ),
      _Tile(
        label: 'Driven since last',
        value: km == null ? '—' : formatKmDelta(km),
        color: AppColors.distance,
        note: km == null ? 'First fill-up' : null,
      ),
      _Tile(
        label: 'Efficiency',
        value: kmPerLiter == null
            ? '—'
            : '${kmPerLiter.toStringAsFixed(2)} km/L',
        color: _verdictColor(entry.isAboveAverage),
        note: kmPerLiter == null
            ? (km == null ? 'Needs a next fill-up' : 'Add liters')
            : _verdictNote(entry.isAboveAverage),
      ),
      _Tile(
        label: 'Cost per km',
        value: costPerKm == null ? '—' : formatCostPerKm(costPerKm),
        color: _verdictColor(entry.isCheaperPerKm),
        note: costPerKm == null ? null : _verdictNote(entry.isCheaperPerKm),
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              Expanded(child: tiles[i + 1]),
            ],
          ),
          if (i + 2 < tiles.length) const SizedBox(height: 10),
        ],
      ],
    );
  }

  static Color _verdictColor(bool? better) => switch (better) {
    true => AppColors.good,
    false => AppColors.bad,
    null => AppColors.text,
  };

  static String? _verdictNote(bool? better) => switch (better) {
    true => 'Better than your average',
    false => 'Worse than your average',
    null => null,
  };
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? note;

  const _Tile({
    required this.label,
    required this.value,
    required this.color,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: _tabular,
              ),
            ),
          ),
          if (note != null)
            Text(
              note!,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color == AppColors.text ? AppColors.textMuted : color,
              ),
            ),
        ],
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  final String notes;

  const _Notes({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(notes, style: const TextStyle(fontSize: 14, height: 1.4)),
      ],
    );
  }
}

class _Photos extends StatelessWidget {
  final List<String> paths;

  const _Photos({required this.paths});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paths.length == 1 ? '1 photo' : '${paths.length} photos',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _thumbSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Semantics(
              button: true,
              label: 'Photo ${i + 1}, open',
              child: AppTappable(
                onTap: () => showFillUpPhotos(context, paths),
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: devicePhoto(
                    paths[i],
                    width: _thumbSize,
                    height: _thumbSize,
                    fit: BoxFit.cover,
                    placeholder: (_) => Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      color: AppColors.surfaceMuted,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
