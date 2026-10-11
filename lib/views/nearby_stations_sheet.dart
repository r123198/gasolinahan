import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_empty_state.dart';
import '../components/brand_logo.dart';
import '../models/station_model.dart';
import '../services/geo.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../viewmodels/dashboard_viewmodel.dart';

const _fuelLabels = {
  FuelType.regular: 'Regular',
  FuelType.premium: 'Premium',
  FuelType.diesel: 'Diesel',
};

/// Opens the nearby stations list. Resolves to the station the user tapped,
/// or null if they closed the sheet. A non-empty [query] filters by name,
/// brand or address.
Future<StationModel?> showNearbyStationsSheet(
  BuildContext context, {
  String? cheapestId,
  double? userLat,
  double? userLng,
  String query = '',
}) {
  return showAppSheet<StationModel>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) => _NearbyStations(
        scrollController: scrollController,
        cheapestId: cheapestId,
        userLat: userLat,
        userLng: userLng,
        query: query.trim().toLowerCase(),
      ),
    ),
  );
}

/// Stations matching [query] (name, brand or address), in list order.
List<StationModel> filterStations(List<StationModel> stations, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return stations;
  return stations
      .where(
        (s) =>
            s.displayName.toLowerCase().contains(q) ||
            s.brand.toLowerCase().contains(q) ||
            s.address.toLowerCase().contains(q),
      )
      .toList();
}

/// "80m", "450m", "1.2km"
String formatDistance(double meters) {
  if (meters < 100) return '${meters.round()}m';
  if (meters < 1000) return '${(meters / 10).round() * 10}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

class _NearbyStations extends StatelessWidget {
  final ScrollController scrollController;
  final String? cheapestId;
  final double? userLat;
  final double? userLng;
  final String query;

  const _NearbyStations({
    required this.scrollController,
    required this.cheapestId,
    required this.userLat,
    required this.userLng,
    required this.query,
  });

  String? _distanceTo(StationModel s) {
    final lat = userLat;
    final lng = userLng;
    if (lat == null || lng == null || (s.latitude == 0 && s.longitude == 0)) {
      return null;
    }
    return formatDistance(haversineMeters(lat, lng, s.latitude, s.longitude));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, vm, _) {
        final stations = filterStations(vm.visibleStations, query);
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _Header(vm: vm, query: query),
            ),
            if (vm.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: AppSpinner(strokeWidth: 2)),
              )
            else if (vm.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: "Can't load stations",
                  subtitle: vm.errorMessage!,
                  actionLabel: 'Try again',
                  onAction: vm.fetchNearbyStations,
                ),
              )
            else if (stations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.local_gas_station_outlined,
                  title: query.isEmpty
                      ? 'No stations found'
                      : 'No stations match "$query"',
                  subtitle: vm.onlyWithPrices
                      ? 'Turn off "With ${_fuelLabels[vm.fuelType]} price" '
                            'to see every station.'
                      : 'Try a different name or area.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: stations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = stations[i];
                    return _StationRow(
                      station: s,
                      price: switch (vm.fuelType) {
                        FuelType.regular => s.regularPrice,
                        FuelType.premium => s.premiumPrice,
                        FuelType.diesel => s.dieselPrice,
                      },
                      fuelLabel: _fuelLabels[vm.fuelType]!,
                      isCheapest: s.id == cheapestId,
                      distance: _distanceTo(s),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final DashboardViewModel vm;
  final String query;

  const _Header({required this.vm, required this.query});

  @override
  Widget build(BuildContext context) {
    // The filter chip gets its own row: beside the title and refresh button
    // it overflowed at large text sizes.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    query.isEmpty ? 'Nearby stations' : 'Results for "$query"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              AppIconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: vm.fetchNearbyStations,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(
                'With ${_fuelLabels[vm.fuelType]} price',
                overflow: TextOverflow.ellipsis,
              ),
              tooltip: vm.onlyWithPrices
                  ? 'Showing only stations with a ${_fuelLabels[vm.fuelType]} '
                        'price. Tap to show all.'
                  : 'Tap to hide stations without a '
                        '${_fuelLabels[vm.fuelType]} price',
              selected: vm.onlyWithPrices,
              onSelected: (_) => vm.toggleOnlyWithPrices(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  final StationModel station;
  final double price;
  final String fuelLabel;
  final bool isCheapest;
  final String? distance;
  final VoidCallback onTap;

  const _StationRow({
    required this.station,
    required this.price,
    required this.fuelLabel,
    required this.isCheapest,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = station;
    final subtitle = [
      ?distance,
      if (s.address.isNotEmpty) s.address else if (s.brand.isNotEmpty) s.brand,
      'Updated ${formatRelativeTime(s.lastUpdated)}',
    ].join(' · ');
    return Material(
      color: isCheapest ? AppColors.goTint : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: AppTappable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: brandLogoWidget(s.brand, 30, stationName: s.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCheapest)
                      const Text(
                        'Cheapest nearby',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goStrong,
                        ),
                      ),
                    Text(
                      s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price > 0 ? formatPhp(price) : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isCheapest ? AppColors.goStrong : AppColors.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '$fuelLabel /L',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
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
