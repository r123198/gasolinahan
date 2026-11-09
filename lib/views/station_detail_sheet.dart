import 'package:flutter/material.dart';

import '../components/brand_logo.dart';
import '../components/detour_card.dart';
import '../models/price_freshness.dart';
import '../models/station_model.dart';
import '../services/app_links.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/tracker_format.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Fetches the station document for hours, phone and website; null when
/// it can't be read (offline, or a station only in the directory).
typedef StationDetailsLoader = Future<StationModel?> Function(String id);

/// Station details: brand, the three pump prices, what the station offers
/// (restroom, store, air, …), hours and contact, and — only when this
/// week's Tuesday price change has passed since the last report — a nudge
/// to report the new prices.
Future<void> showStationDetailSheet(
  BuildContext context, {
  required StationModel station,
  VoidCallback? onReport,
  double? userLat,
  double? userLng,
  StationDetailsLoader? loadDetails,
  DateTime? now,
}) {
  return showAppSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StationDetailSheet(
      station: station,
      userLat: userLat,
      userLng: userLng,
      loadDetails: loadDetails,
      now: now ?? DateTime.now(),
      onReport: onReport == null
          ? null
          : () {
              Navigator.pop(sheetContext);
              onReport();
            },
    ),
  );
}

class StationDetailSheet extends StatefulWidget {
  final StationModel station;
  final double? userLat;
  final double? userLng;
  final StationDetailsLoader? loadDetails;

  /// Null where the map is read-only (the web): no way to report is offered.
  final VoidCallback? onReport;
  final DateTime now;

  const StationDetailSheet({
    super.key,
    required this.station,
    required this.now,
    this.onReport,
    this.userLat,
    this.userLng,
    this.loadDetails,
  });

  @override
  State<StationDetailSheet> createState() => _StationDetailSheetState();
}

class _StationDetailSheetState extends State<StationDetailSheet> {
  late StationModel _station = widget.station;

  @override
  void initState() {
    super.initState();
    final load = widget.loadDetails;
    if (load != null && !_hasDetails(_station)) {
      load(_station.id).then((full) {
        if (full != null && mounted) setState(() => _station = full);
      });
    }
  }

  static bool _hasDetails(StationModel s) =>
      s.openingHours.isNotEmpty || s.phone.isNotEmpty || s.website.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = _station;
    final userLat = widget.userLat;
    final userLng = widget.userLng;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(station: s),
              const SizedBox(height: 20),
              _Prices(station: s),
              const SizedBox(height: 12),
              if (!s.hasPrices)
                _NoPricesYet(onReport: widget.onReport)
              else if (pricesMayHaveChanged(s.lastUpdated, widget.now))
                _UpdateNudge(
                  reportedAt: s.lastUpdated,
                  onReport: widget.onReport,
                )
              else
                _Current(reportedAt: s.lastUpdated),
              const SizedBox(height: 20),
              _Amenities(station: s),
              if (s.amenities.open24Hours == true ||
                  s.openingHours.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Hours(station: s, now: widget.now),
              ],
              if (s.phone.isNotEmpty ||
                  s.website.isNotEmpty ||
                  s.mapsUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Contact(station: s),
              ],
              // A station without coordinates (0,0) has no meaningful detour.
              if (userLat != null && userLng != null && s.isPlaced) ...[
                const SizedBox(height: 16),
                DetourCard(station: s, userLat: userLat, userLng: userLng),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final StationModel station;

  const _Header({required this.station});

  @override
  Widget build(BuildContext context) {
    final s = station;
    final subtitle = s.address.isNotEmpty ? s.address : s.brand;
    final rating = s.rating;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: brandAccent(s.brand), width: 2),
          ),
          child: ExcludeSemantics(
            child: brandLogoWidget(s.brand, 38, stationName: s.name),
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
                  s.displayName,
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
              if (rating != null || !s.isOpen) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (rating != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            TextSpan(
                              text: ' ${rating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFeatures: _tabular,
                              ),
                            ),
                            if (s.reviewCount > 0)
                              TextSpan(
                                text:
                                    ' (${s.reviewCount} '
                                    '${s.reviewCount == 1 ? 'review' : 'reviews'})',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    if (!s.isOpen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s.status == 'permanently_closed'
                              ? 'Permanently closed'
                              : 'Temporarily closed',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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

/// Nobody has reported this station's prices yet.
class _NoPricesYet extends StatelessWidget {
  final VoidCallback? onReport;

  const _NoPricesYet({required this.onReport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No prices reported yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (onReport != null) ...[
            const SizedBox(height: 4),
            const Text(
              'Be the first: snap the price board and everyone nearby sees '
              'what this station charges.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Report prices'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the last report predates this week's Tuesday price change.
class _UpdateNudge extends StatelessWidget {
  final DateTime reportedAt;
  final VoidCallback? onReport;

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
              '${formatDate(reportedAt)}.'
              '${onReport == null ? '' : ' At this station? Snap the price '
                        'board so everyone sees this week\'s prices.'}',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (onReport != null) ...[
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

typedef _Amenity = ({String label, IconData icon, bool? value});

/// What the station offers, as chips: a tick for yes, a strike for a
/// listed no. Unlisted amenities are left out rather than guessed.
class _Amenities extends StatelessWidget {
  final StationModel station;

  const _Amenities({required this.station});

  @override
  Widget build(BuildContext context) {
    final a = station.amenities;
    final store = a.convenienceStore == true
        ? true
        : station.nearbyStore.isNotEmpty
        ? true
        : a.convenienceStore;
    final items = <_Amenity>[
      (label: 'Restroom', icon: Icons.wc_outlined, value: a.restroom),
      (
        label: 'Accessible restroom',
        icon: Icons.accessible_outlined,
        value: a.accessibleRestroom,
      ),
      (
        label: station.nearbyStore.isNotEmpty && a.convenienceStore != true
            ? '${station.nearbyStore} next door'
            : 'Convenience store',
        icon: Icons.storefront_outlined,
        value: store,
      ),
      (label: 'Air pump', icon: Icons.tire_repair_outlined, value: a.airPump),
      (
        label: 'Car wash',
        icon: Icons.local_car_wash_outlined,
        value: a.carWash,
      ),
      (label: 'Oil change', icon: Icons.build_outlined, value: a.oilChange),
      (label: 'ATM', icon: Icons.atm_outlined, value: a.atm),
      (
        label: 'Cards accepted',
        icon: Icons.credit_card_outlined,
        value: a.cardsAccepted,
      ),
      (
        label: 'Open 24 hours',
        icon: Icons.schedule_outlined,
        value: a.open24Hours,
      ),
    ];
    final known = [
      for (final i in items)
        if (i.value != null) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('At this station'),
        if (known.isEmpty)
          const Text(
            'Amenities not listed yet.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final i in known) _AmenityChip(item: i)],
          ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final _Amenity item;

  const _AmenityChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final yes = item.value == true;
    return Semantics(
      label: yes ? item.label : 'No ${item.label.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: yes ? AppColors.goTint : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: yes ? AppColors.goStrong : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: yes ? AppColors.goStrong : AppColors.textMuted,
                decoration: yes ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Today's hours, with the full week behind a tap.
class _Hours extends StatefulWidget {
  final StationModel station;
  final DateTime now;

  const _Hours({required this.station, required this.now});

  @override
  State<_Hours> createState() => _HoursState();
}

class _HoursState extends State<_Hours> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final today = _weekdays[widget.now.weekday - 1];
    final hours = s.openingHours;
    final todayText = s.amenities.open24Hours == true
        ? 'Open 24 hours'
        : hours[today] ?? 'Hours not listed for today';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Hours'),
        Row(
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 18,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$today · $todayText',
                style: const TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ),
            if (hours.length > 1)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Hide' : 'All days'),
              ),
          ],
        ),
        if (_expanded)
          for (final day in _weekdays)
            if (hours[day] case final h?)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: day == today
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        h,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
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

/// Call, website and Google Maps, when known.
class _Contact extends StatelessWidget {
  final StationModel station;

  const _Contact({required this.station});

  Future<void> _open(BuildContext context, Uri url) async {
    if (!await openLink(url) && context.mounted) {
      showAppToast(context, "Couldn't open that on this phone.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = station;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (s.phone.isNotEmpty)
          _LinkChip(
            icon: Icons.call_outlined,
            label: s.phone,
            onTap: () => _open(context, Uri(scheme: 'tel', path: s.phone)),
          ),
        if (s.website.isNotEmpty)
          if (Uri.tryParse(s.website) case final url? when url.hasScheme)
            _LinkChip(
              icon: Icons.language_outlined,
              label: 'Website',
              onTap: () => _open(context, url),
            ),
        if (s.mapsUrl.isNotEmpty)
          if (Uri.tryParse(s.mapsUrl) case final url? when url.hasScheme)
            _LinkChip(
              icon: Icons.map_outlined,
              label: 'Open in Google Maps',
              onTap: () => _open(context, url),
            ),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.outline)),
      clipBehavior: Clip.antiAlias,
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
