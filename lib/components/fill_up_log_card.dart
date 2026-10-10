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

const _fuelLabels = {
  'regular': 'Regular',
  'premium': 'Premium',
  'diesel': 'Diesel',
};

enum FillUpAction { edit, delete }

/// One fill-up in the Tracker log: what was paid, the odometer, and the
/// efficiency since the previous fill-up.
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
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(entry: entry, onMore: () => _showMenu(context)),
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 12, 8),
                child: Divider(),
              ),
              _Details(entry: entry, onStationTap: onStationTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FillUpLogEntry entry;
  final VoidCallback onMore;

  const _Header({required this.entry, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    final liters = fill.liters;
    final price = fill.effectivePricePerLiter;
    final fuel = _fuelLabels[fill.fuelType] ?? fill.fuelType;
    const tabular = [FontFeature.tabularFigures()];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: brandAccent(fill.brand).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: ExcludeSemantics(child: brandLogoWidget(fill.brand, 32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(fill.timestamp),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatPesosExact(fill.amountSpent),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.water_drop_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    TextSpan(
                      text: liters == null
                          ? 'Liters not set'
                          : formatLiters(liters),
                    ),
                    if (price != null)
                      TextSpan(text: '  →  ${formatPricePerLiter(price)}'),
                    TextSpan(
                      text: '  ·  $fuel',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 14, fontFeatures: tabular),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatKm(fill.odometerKm),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: tabular,
              ),
            ),
            if (entry.kmSincePrevious != null)
              Text(
                formatKmDelta(entry.kmSincePrevious!),
                semanticsLabel:
                    '${entry.kmSincePrevious!.round()} km since last fill-up',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFeatures: tabular,
                ),
              ),
          ],
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

class _Details extends StatelessWidget {
  final FillUpLogEntry entry;
  final VoidCallback onStationTap;

  const _Details({required this.entry, required this.onStationTap});

  @override
  Widget build(BuildContext context) {
    final fill = entry.fillUp;
    final kmPerLiter = entry.kmPerLiter;
    final costPerKm = entry.costPerKm;
    final photos = fill.photoPaths;
    return Column(
      children: [
        if (kmPerLiter != null || costPerKm != null)
          _DetailRow(
            icon: entry.isAboveAverage ? Icons.trending_up : Icons.show_chart,
            iconColor: entry.isAboveAverage ? AppColors.goStrong : null,
            semanticsLabel: [
              if (kmPerLiter != null)
                '${kmPerLiter.toStringAsFixed(2)} kilometers per liter',
              if (entry.isAboveAverage) 'better than your average',
              if (costPerKm != null)
                '${costPerKm.toStringAsFixed(2)} pesos per kilometer',
            ].join(', '),
            child: Text.rich(
              TextSpan(
                children: [
                  if (kmPerLiter != null)
                    TextSpan(
                      text: '${kmPerLiter.toStringAsFixed(2)} km/L',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: entry.isAboveAverage
                            ? AppColors.goStrong
                            : AppColors.text,
                      ),
                    ),
                  if (kmPerLiter != null && costPerKm != null)
                    const TextSpan(text: '   '),
                  if (costPerKm != null)
                    TextSpan(text: formatCostPerKm(costPerKm)),
                ],
              ),
              style: const TextStyle(
                fontSize: 14,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        _DetailRow(
          icon: Icons.place_outlined,
          onTap: onStationTap,
          semanticsLabel: 'Station ${fill.stationName}, show history',
          child: Text(
            fill.stationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        if (fill.notes.isNotEmpty)
          _DetailRow(
            icon: Icons.sticky_note_2_outlined,
            child: Text(
              fill.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        if (photos.isNotEmpty)
          _DetailRow(
            icon: Icons.photo_camera_outlined,
            onTap: () => showFillUpPhotos(context, photos),
            semanticsLabel: '${photos.length} photos, view',
            child: Text(
              photos.length == 1 ? '1 photo' : '${photos.length} photos',
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const _DetailRow({
    required this.icon,
    required this.child,
    this.iconColor,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
    final labelled = semanticsLabel == null
        ? row
        : Semantics(
            label: semanticsLabel,
            button: onTap != null,
            excludeSemantics: true,
            child: row,
          );
    if (onTap == null) return labelled;
    return AppTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: labelled,
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
