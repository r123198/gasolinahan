import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../models/station_model.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/app_format.dart';
import '../components/app_primary_button.dart';
import 'dashboard_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  double? _userLat;
  double? _userLng;
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final loc = await _location.getLocation();
      if (loc.latitude != null && loc.longitude != null && mounted) {
        setState(() {
          _userLat = loc.latitude;
          _userLng = loc.longitude;
        });
      }
    } catch (_) {}
  }

  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _formatDist(double meters) {
    if (meters < 100) return '${meters.round()}m';
    if (meters < 1000) return '${(meters / 10).round() * 10}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  List<_RankedStation> _rankStations(
      List<StationModel> stations, FuelType fuelType) {
    double priceOf(StationModel s) => switch (fuelType) {
          FuelType.regular => s.regularPrice,
          FuelType.premium => s.premiumPrice,
          FuelType.diesel => s.dieselPrice,
        };

    final ranked = <_RankedStation>[];
    for (final s in stations) {
      final price = priceOf(s);
      if (price <= 0) continue;
      double? dist;
      if (_userLat != null &&
          _userLng != null &&
          (s.latitude != 0 || s.longitude != 0)) {
        dist = _haversineMeters(_userLat!, _userLng!, s.latitude, s.longitude);
      }
      ranked.add(_RankedStation(station: s, price: price, distance: dist));
    }

    ranked.sort((a, b) {
      final priceCmp = a.price.compareTo(b.price);
      if (priceCmp != 0) return priceCmp;
      if (a.distance != null && b.distance != null) {
        return a.distance!.compareTo(b.distance!);
      }
      return 0;
    });

    return ranked;
  }

  // ── Station detail modal ────────────────────────────────────

  void _showStationDetail(StationModel station, {String? distLabel}) {
    final accent = brandAccent(station.brand);

    showAppSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 40,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.20),
                      ),
                    ),
                    child: brandLogoWidget(station.brand, 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          station.address.isNotEmpty
                              ? station.address
                              : station.brand,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (station.brand.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        station.brand,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Prices
              Row(
                children: [
                  _buildPriceCard('Regular', station.regularPrice,
                      const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _buildPriceCard('Premium', station.premiumPrice,
                      const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  _buildPriceCard('Diesel', station.dieselPrice,
                      const Color(0xFF16A34A)),
                ],
              ),
              const SizedBox(height: 16),
              // Distance + Updated time
              Row(
                children: [
                  if (distLabel != null) ...[
                    Icon(Icons.near_me_rounded,
                        size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      distLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${formatRelativeTime(station.lastUpdated)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action
              AppPrimaryButton(
                label: 'Update Prices',
                trailingIcon: Icons.add_a_photo_outlined,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/report');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceCard(String label, double price, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.10)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.70),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price > 0 ? formatPhp(price) : '\u2014',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: price > 0 ? color : const Color(0xFFD4D4D8),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, vm, _) {
        final ranked = _rankStations(vm.nearbyStations, vm.fuelType);

        return RefreshIndicator(
          onRefresh: () async {
            vm.fetchNearbyStations();
            await _fetchLocation();
          },
          color: const Color(0xFF111827),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nearby Stations',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pull down to refresh',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFuelChips(vm),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Loading
              if (vm.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: AppSpinner(strokeWidth: 2),
                  ),
                )
              // Error
              else if (vm.errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 16),
                          Text(
                            vm.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryButton(
                            label: 'Try again',
                            onPressed: vm.fetchNearbyStations,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              // Empty
              else if (ranked.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_gas_station_outlined,
                              size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 16),
                          const Text(
                            'No stations with prices found',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryButton(
                            label: 'Report prices',
                            onPressed: () =>
                                Navigator.pushNamed(context, '/report'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              // Grid
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final r = ranked[i];
                        final isFirst = i == 0;
                        final distLabel = r.distance != null
                            ? _formatDist(r.distance!)
                            : null;
                        return _StationCard(
                          station: r.station,
                          price: r.price,
                          distance: distLabel,
                          fuelType: vm.fuelType,
                          isCheapest: isFirst,
                          onTap: () => _showStationDetail(
                            r.station,
                            distLabel: distLabel,
                          ),
                        );
                      },
                      childCount: ranked.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFuelChips(DashboardViewModel vm) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, FuelType type) {
      final selected = vm.fuelType == type;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => vm.setFuelType(type),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        selectedColor: scheme.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      children: [
        chip('Regular', FuelType.regular),
        const SizedBox(width: 8),
        chip('Premium', FuelType.premium),
        const SizedBox(width: 8),
        chip('Diesel', FuelType.diesel),
      ],
    );
  }
}

class _RankedStation {
  final StationModel station;
  final double price;
  final double? distance;
  const _RankedStation({
    required this.station,
    required this.price,
    required this.distance,
  });
}

class _StationCard extends StatelessWidget {
  final StationModel station;
  final double price;
  final String? distance;
  final FuelType fuelType;
  final bool isCheapest;
  final VoidCallback onTap;

  const _StationCard({
    required this.station,
    required this.price,
    required this.distance,
    required this.fuelType,
    required this.isCheapest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = brandAccent(station.brand);
    final fuelLabel = switch (fuelType) {
      FuelType.regular => 'Regular',
      FuelType.premium => 'Premium',
      FuelType.diesel => 'Diesel',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCheapest
                ? const Color(0xFF22C55E).withValues(alpha: 0.40)
                : const Color(0xFFF1F5F9),
            width: isCheapest ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCheapest
                  ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                  : const Color(0x08000000),
              blurRadius: isCheapest ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: logo + cheapest badge / distance
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.15),
                    ),
                  ),
                  child: brandLogoWidget(station.brand, 28),
                ),
                const Spacer(),
                if (isCheapest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CHEAPEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 10,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          distance!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // Brand
            Text(
              station.brand.isNotEmpty ? station.brand : 'Station',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),

            // Name
            Text(
              station.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Price + fuel type
            Row(
              children: [
                Text(
                  formatPhp(price),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isCheapest
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '/L',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              fuelLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
