import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../models/brand_registry.dart';
import '../models/station_model.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../components/track_me_button.dart';
import '../components/detour_card.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../components/app_empty_state.dart';
import '../components/app_primary_button.dart';
import 'home_view.dart';

Widget brandLogoWidget(String brandName, double size) {
  final brand = BrandRegistry.findByName(brandName);
  if (brand != null) return brand.logo(size: size);
  return Icon(Icons.local_gas_station_rounded, size: size * 0.7, color: brandAccent(brandName));
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final MapController _mapController = MapController();
  final Location _location = Location();

  // Default center: Metro Manila (Makati area)
  static const _defaultCenter = LatLng(14.5648, 121.0453);
  static const _defaultZoom = 13.0;

  // User location for distance calculations
  double? _userLat;
  double? _userLng;

  // Search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().listenToStations();
      context.read<TripViewModel>().startMonitoring();
      _initLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        return;
      }
    }

    try {
      final loc = await _location.getLocation();
      if (loc.latitude != null && loc.longitude != null && mounted) {
        setState(() {
          _userLat = loc.latitude;
          _userLng = loc.longitude;
        });
        _mapController.move(
          LatLng(loc.latitude!, loc.longitude!),
          14.0,
        );
      }
    } catch (_) {}
  }

  Future<void> _goToMyLocation() async {
    try {
      final loc = await _location.getLocation();
      if (loc.latitude != null && loc.longitude != null) {
        setState(() {
          _userLat = loc.latitude;
          _userLng = loc.longitude;
        });
        _mapController.move(
          LatLng(loc.latitude!, loc.longitude!),
          15.0,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Could not get current location');
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.pushNamed(context, '/report');
      return;
    }
    if (index == 3) {
      Navigator.pushNamed(context, '/profile');
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showStationDetail(StationModel station) {
    final scheme = Theme.of(context).colorScheme;
    final accent = brandAccent(station.brand);

    // Move map to station
    _mapController.move(LatLng(station.latitude, station.longitude), 16.0);

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
                  _buildPriceCard(
                    'Regular',
                    station.regularPrice,
                    const Color(0xFF2563EB),
                    scheme,
                  ),
                  const SizedBox(width: 8),
                  _buildPriceCard(
                    'Premium',
                    station.premiumPrice,
                    const Color(0xFFDC2626),
                    scheme,
                  ),
                  const SizedBox(width: 8),
                  _buildPriceCard(
                    'Diesel',
                    station.dieselPrice,
                    const Color(0xFF16A34A),
                    scheme,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Updated time
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
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
              const SizedBox(height: 16),
              if (_userLat != null && _userLng != null)
                DetourCard(
                  station: station,
                  userLat: _userLat!,
                  userLng: _userLng!,
                ),
              // Actions
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

  Widget _buildPriceCard(
    String label,
    double price,
    Color color,
    ColorScheme scheme,
  ) {
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

  /// Haversine distance in meters
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

  /// Find the cheapest station among nearby ones (within 5km) for the given fuel type.
  /// Returns the station ID or null.
  String? _cheapestNearbyId(List<StationModel> stations, FuelType fuelType) {
    if (_userLat == null || _userLng == null) return null;

    double priceOf(StationModel s) => switch (fuelType) {
          FuelType.regular => s.regularPrice,
          FuelType.premium => s.premiumPrice,
          FuelType.diesel => s.dieselPrice,
        };

    StationModel? best;
    double bestPrice = double.infinity;

    for (final s in stations) {
      if (s.latitude == 0 && s.longitude == 0) continue;
      final dist = _haversineMeters(_userLat!, _userLng!, s.latitude, s.longitude);
      if (dist > 5000) continue; // only within 5km
      final p = priceOf(s);
      if (p <= 0) continue; // skip stations without price
      if (p < bestPrice) {
        bestPrice = p;
        best = s;
      }
    }
    return best?.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF4F6F9),
      body: _selectedIndex == 0
          ? SafeArea(
              bottom: false,
              child: const HomeView(),
            )
          : _buildMapTab(scheme),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: isCupertino(context)
              ? _buildCupertinoTabBar(scheme)
              : NavigationBar(
            selectedIndex: _selectedIndex,
            backgroundColor: Colors.white.withValues(alpha: 0.96),
            indicatorColor: scheme.primary.withValues(alpha: 0.10),
            onDestinationSelected: _onItemTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_a_photo_outlined),
                selectedIcon: Icon(Icons.add_a_photo),
                label: 'Report',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapTab(ColorScheme scheme) {
    return Stack(
      children: [
        Positioned.fill(child: _buildMap()),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchBar(context)),
                    const SizedBox(width: 12),
                    _buildIconButton(
                      context: context,
                      icon: Icons.my_location_outlined,
                      onPressed: _goToMyLocation,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FuelChips(onMapTap: () {}),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: TrackMeButton(),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 210,
          child: Column(
            children: [
              _buildFloatingButton(
                icon: Icons.layers_outlined,
                bgColor: Colors.white,
                iconColor: scheme.primary,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              _buildFloatingButton(
                icon: Icons.near_me_outlined,
                bgColor: scheme.primary,
                iconColor: Colors.white,
                onPressed: _goToMyLocation,
              ),
            ],
          ),
        ),
        Consumer<DashboardViewModel>(
          builder: (context, vm, _) {
            return _StationsSheet(
              controller: _sheetController,
              cheapestId: _cheapestNearbyId(vm.nearbyStations, vm.fuelType),
              userLat: _userLat,
              userLng: _userLng,
              onStationTap: (station) {
                _showStationDetail(station);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMap() {
    return Consumer<DashboardViewModel>(
      builder: (context, vm, _) {
        final stations = vm.nearbyStations;
        final cheapestId = _cheapestNearbyId(stations, vm.fuelType);
        final markers = stations.map((s) {
          final price = switch (vm.fuelType) {
            FuelType.regular => s.regularPrice,
            FuelType.premium => s.premiumPrice,
            FuelType.diesel => s.dieselPrice,
          };
          final accent = brandAccent(s.brand);
          final isCheapest = s.id == cheapestId;
          final markerColor = isCheapest ? const Color(0xFF16A34A) : Colors.white;
          final borderColor = isCheapest
              ? const Color(0xFF16A34A)
              : accent.withValues(alpha: 0.25);
          final textColor = isCheapest ? Colors.white : const Color(0xFF18181B);
          return Marker(
            point: LatLng(s.latitude, s.longitude),
            width: 160,
            height: isCheapest ? 78 : 60,
            child: GestureDetector(
              onTap: () => _showStationDetail(s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCheapest)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CHEAPEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: isCheapest ? 2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isCheapest
                              ? const Color(0x3316A34A)
                              : const Color(0x22000000),
                          blurRadius: isCheapest ? 16 : 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isCheapest ? Colors.white : accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatPricePerLiter(price),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Triangle pointer
                  CustomPaint(
                    size: const Size(14, 8),
                    painter: _TrianglePainter(
                      color: markerColor,
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: _defaultZoom,
            minZoom: 5,
            maxZoom: 18,
            // Disable rotation — pinch only zooms
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.flingAnimation |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            // Official OpenStreetMap tiles: free, no API key.
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gasolinahan.app',
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
            CurrentLocationLayer(
              style: LocationMarkerStyle(
                marker: const DefaultLocationMarker(
                  color: Color(0xFF2563EB),
                  child: Icon(Icons.circle, color: Colors.white, size: 12),
                ),
                markerSize: const Size.square(24),
                accuracyCircleColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.08),
                headingSectorColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.30),
              ),
            ),
            Consumer<TripViewModel>(
              builder: (context, trips, _) => PolylineLayer(
                polylines: [
                  if (trips.livePoints.length > 1)
                    Polyline(
                      points: [
                        for (final p in trips.livePoints)
                          LatLng(p.latitude, p.longitude),
                      ],
                      strokeWidth: 5,
                      color: const Color(0xFFDC2626),
                    ),
                ],
              ),
            ),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    if (isCupertino(context)) return _buildCupertinoSearchBar(context);
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search station, brand, area',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? AppIconButton(
                onPressed: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                },
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
              )
            : null,
      ),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildCupertinoSearchBar(BuildContext context) {
    return CupertinoTextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      placeholder: 'Search station, brand, area',
      placeholderStyle: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: const Color(0xFF94A3B8),
      ),
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      prefix: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.search, color: Color(0xFF64748B)),
      ),
      suffix: _searchController.text.isNotEmpty
          ? AppIconButton(
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              tooltip: 'Clear',
            )
          : null,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildCupertinoTabBar(ColorScheme scheme) {
    const items = [
      (Icons.home_outlined, Icons.home, 'Home'),
      (Icons.map_outlined, Icons.map, 'Map'),
      (Icons.add_a_photo_outlined, Icons.add_a_photo, 'Report'),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];
    return CupertinoTabBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      border: null,
      activeColor: scheme.primary,
      inactiveColor: scheme.onSurfaceVariant,
      items: [
        for (final (icon, activeIcon, label) in items)
          BottomNavigationBarItem(
            icon: Icon(icon),
            activeIcon: Icon(activeIcon),
            label: label,
          ),
      ],
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: AppIconButton(
        icon: Icon(icon, color: scheme.primary),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: AppIconButton(
        icon: Icon(icon, size: 20, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }
}

/// Paints a small triangle pointer below the marker bubble
class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _TrianglePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    // Fill
    canvas.drawPath(path, Paint()..color = color);
    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FuelChips extends StatelessWidget {
  final VoidCallback onMapTap;
  const _FuelChips({required this.onMapTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<DashboardViewModel>(
      builder: (context, vm, _) {
        Widget fuelChip(String label, FuelType type) {
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
            backgroundColor: Colors.white.withValues(alpha: 0.96),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              fuelChip('Regular', FuelType.regular),
              const SizedBox(width: 8),
              fuelChip('Premium', FuelType.premium),
              const SizedBox(width: 8),
              fuelChip('Diesel', FuelType.diesel),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Only with prices'),
                selected: vm.onlyWithPrices,
                onSelected: (_) => vm.toggleOnlyWithPrices(),
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                selectedColor: scheme.secondary.withValues(alpha: 0.18),
                backgroundColor: Colors.white.withValues(alpha: 0.96),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              ActionChip(
                label: const Text('Focus map'),
                onPressed: onMapTap,
                backgroundColor: scheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StationsSheet extends StatelessWidget {
  final DraggableScrollableController controller;
  final void Function(StationModel station) onStationTap;
  final String? cheapestId;
  final double? userLat;
  final double? userLng;
  const _StationsSheet({
    required this.controller,
    required this.onStationTap,
    this.cheapestId,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.42,
      minChildSize: 0.14,
      maxChildSize: 0.78,
      snap: true,
      snapSizes: const [0.14, 0.42, 0.78],
      builder: (context, scrollController) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x0A000000)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 44,
                offset: Offset(0, -10),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: Consumer<DashboardViewModel>(
                  builder: (context, vm, _) {
                    if (vm.isLoading) {
                      return _buildSheetHeader(context, scrollController,
                        child: const Center(
                          child: AppSpinner(strokeWidth: 2),
                        ),
                      );
                    }
                    if (vm.errorMessage != null) {
                      return _buildSheetHeader(context, scrollController,
                        child: AppEmptyState(
                          title: "Can't load stations",
                          subtitle: vm.errorMessage!,
                          actionLabel: 'Try again',
                          onAction: vm.fetchNearbyStations,
                        ),
                      );
                    }
                    final stations = vm.visibleStations;
                    if (stations.isEmpty) {
                      return _buildSheetHeader(context, scrollController,
                        child: AppEmptyState(
                          title: 'No stations found',
                          subtitle: vm.onlyWithPrices
                              ? 'Try turning off "Only with prices".'
                              : 'Try again in a different area.',
                          actionLabel: 'Report prices',
                          onAction: () =>
                              Navigator.pushNamed(context, '/report'),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: stations.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Nearby stations',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                AppIconButton(
                                  onPressed: () {
                                    context
                                        .read<DashboardViewModel>()
                                        .fetchNearbyStations();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                          );
                        }
                        final s = stations[i - 1];
                        final accent = brandAccent(s.brand);
                        final price = switch (vm.fuelType) {
                          FuelType.regular => s.regularPrice,
                          FuelType.premium => s.premiumPrice,
                          FuelType.diesel => s.dieselPrice,
                        };
                        final fuelLabel = switch (vm.fuelType) {
                          FuelType.regular => 'Regular',
                          FuelType.premium => 'Premium',
                          FuelType.diesel => 'Diesel',
                        };
                        final isCheapest = s.id == cheapestId;

                        // Calculate distance from user
                        String? distLabel;
                        if (userLat != null &&
                            userLng != null &&
                            (s.latitude != 0 || s.longitude != 0)) {
                          final dist = _DashboardViewState._haversineMeters(
                            userLat!,
                            userLng!,
                            s.latitude,
                            s.longitude,
                          );
                          if (dist < 100) {
                            distLabel = '${dist.round()}m';
                          } else if (dist < 1000) {
                            distLabel =
                                '${(dist / 10).round() * 10}m';
                          } else {
                            distLabel =
                                '${(dist / 1000).toStringAsFixed(1)}km';
                          }
                        }

                        return AppTappable(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => onStationTap(s),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isCheapest
                                  ? const Color(0xFF16A34A)
                                      .withValues(alpha: 0.06)
                                  : scheme.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isCheapest
                                    ? const Color(0xFF16A34A)
                                        .withValues(alpha: 0.30)
                                    : const Color(0x0A000000),
                                width: isCheapest ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isCheapest)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'CHEAPEST NEARBY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: isCheapest
                                            ? const Color(0xFF16A34A)
                                                .withValues(alpha: 0.14)
                                            : accent
                                                .withValues(alpha: 0.14),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isCheapest
                                              ? const Color(0xFF16A34A)
                                                  .withValues(alpha: 0.30)
                                              : accent.withValues(
                                                  alpha: 0.22),
                                        ),
                                      ),
                                      child: brandLogoWidget(s.brand, 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  s.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isCheapest
                                                      ? const Color(
                                                              0xFF16A34A)
                                                          .withValues(
                                                              alpha: 0.12)
                                                      : scheme.primary
                                                          .withValues(
                                                              alpha: 0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  '$fuelLabel \u2022 ${formatPricePerLiter(price)}',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    fontSize: 12,
                                                    color: isCheapest
                                                        ? const Color(
                                                            0xFF16A34A)
                                                        : scheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            s.address.isEmpty
                                                ? (s.brand.isEmpty
                                                    ? '\u2014'
                                                    : s.brand)
                                                : s.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: scheme
                                                      .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  s.brand.isEmpty
                                                      ? 'Station'
                                                      : s.brand,
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (distLabel != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF2563EB)
                                                        .withValues(
                                                            alpha: 0.08),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(999),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .near_me_outlined,
                                                        size: 11,
                                                        color: Color(
                                                            0xFF2563EB),
                                                      ),
                                                      const SizedBox(
                                                          width: 3),
                                                      Text(
                                                        distLabel,
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w800,
                                                          fontSize: 11,
                                                          color: Color(
                                                              0xFF2563EB),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Updated ${formatRelativeTime(s.lastUpdated)}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader(
    BuildContext context,
    ScrollController scrollController, {
    required Widget child,
  }) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nearby stations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                AppIconButton(
                  onPressed: () {
                    context.read<DashboardViewModel>().fetchNearbyStations();
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ),
        SliverFillRemaining(child: child),
      ],
    );
  }
}
