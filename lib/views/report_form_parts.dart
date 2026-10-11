import 'dart:io';

import 'package:flutter/material.dart';

import '../components/brand_logo.dart';
import '../models/station_model.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import '../viewmodels/report_viewmodel.dart';
import 'fill_up_form_parts.dart' show FormLabel;

/// Within this distance you count as being at the station.
const nearStationMeters = 200.0;

/// White rounded block with a sentence-case title, used for each step of
/// the report form.
class ReportSection extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;

  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormLabel(title),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                hint!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// The captured board photo with what the scan recognised.
class ReportPhotoPreview extends StatelessWidget {
  final String imagePath;
  final String? detectedBrand;

  const ReportPhotoPreview({
    super.key,
    required this.imagePath,
    this.detectedBrand,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              semanticLabel: 'Your photo of the price board',
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.onDarkGood,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      detectedBrand != null
                          ? '$detectedBrand board detected'
                          : 'Photo captured',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsed "what the scan read" text, for checking the detected prices.
class ReportScanText extends StatelessWidget {
  final String text;

  const ReportScanText({super.key, required this.text});

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
          leading: const Icon(Icons.document_scanner_outlined),
          iconColor: AppColors.ink,
          title: const Text(
            'What the scan read',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.length > 400 ? '${text.substring(0, 400)}…' : text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nearby stations as logo cards; once one is picked, a summary with a
/// "Change" button and a warning if the user seems far from it.
class ReportStationPicker extends StatelessWidget {
  final List<StationModel> stations;
  final Map<String, double> distances;
  final StationModel? selected;
  final String emptyMessage;
  final ValueChanged<StationModel> onSelect;
  final VoidCallback onClear;

  const ReportStationPicker({
    super.key,
    required this.stations,
    required this.distances,
    required this.selected,
    required this.emptyMessage,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final picked = selected;
    if (picked != null) {
      return _SelectedStation(
        station: picked,
        distance: distances[picked.id],
        onClear: onClear,
      );
    }
    if (stations.isEmpty) {
      return Text(
        emptyMessage,
        style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
      );
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: stations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _StationCard(
          station: stations[i],
          distance: distances[stations[i].id],
          onTap: () => onSelect(stations[i]),
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final StationModel station;
  final double? distance;
  final VoidCallback onTap;

  const _StationCard({
    required this.station,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = distance;
    final isNear = d != null && d <= nearStationMeters;
    return Semantics(
      button: true,
      label:
          '${station.name}'
          '${d == null ? '' : ', ${ReportViewModel.formatDistance(d)} away'}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: isNear ? AppColors.goTint : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: AppTappable(
          onTap: onTap,
          child: Container(
            width: 148,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LogoBadge(station: station, size: 36),
                    const Spacer(),
                    if (d != null)
                      Text(
                        ReportViewModel.formatDistance(d),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isNear ? AppColors.good : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  station.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedStation extends StatelessWidget {
  final StationModel station;
  final double? distance;
  final VoidCallback onClear;

  const _SelectedStation({
    required this.station,
    required this.distance,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final d = distance;
    final isNear = d != null && d <= nearStationMeters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _LogoBadge(station: station, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (d != null)
                    Row(
                      children: [
                        Icon(
                          isNear ? Icons.check_circle : Icons.info_outline,
                          size: 14,
                          color: isNear ? AppColors.good : AppColors.bad,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isNear
                              ? "You're here"
                              : '${ReportViewModel.formatDistance(d)} away',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isNear ? AppColors.good : AppColors.bad,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              child: const Text('Change'),
            ),
          ],
        ),
        if (d != null && !isNear)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.bad,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're ${ReportViewModel.formatDistance(d)} from this "
                    "station. Reports work best when you're at the pump.",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.text,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  final StationModel station;
  final double size;

  const _LogoBadge({required this.station, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider),
      ),
      child: ExcludeSemantics(
        child: brandLogoWidget(
          station.brand,
          size * 0.7,
          stationName: station.name,
        ),
      ),
    );
  }
}
