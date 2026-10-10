import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../models/station_model.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/fill_up_nudge_viewmodel.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import 'fill_up_form_sheet.dart';
import '../components/detour_card.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../components/app_primary_button.dart';
import '../components/brand_logo.dart';
import '../components/map_bottom_controls.dart';
import '../services/heading_stream.dart';
import 'nearby_stations_sheet.dart';
import 'home_view.dart';
import 'profile_view.dart';

/// One bottom-navigation destination.
typedef _NavTab = ({IconData icon, IconData selectedIcon, String label});

const List<_NavTab> _tabs = [
  (
    icon: Icons.local_gas_station_outlined,
    selectedIcon: Icons.local_gas_station,
    label: 'Tracker',
  ),
  (icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Prices'),
  (
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle,
    label: 'Account',
  ),
];

/// Zoom used when centering on the user.
const _followZoom = 16.0;

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;

  /// Tells the location layer to re-center (value = zoom) on demand.
  final StreamController<double?> _alignToUser = StreamController.broadcast();

  /// While true the map keeps the user's dot centered as they move; any
  /// pan by the user turns it off.
  bool _followUser = false;

  /// Created once: the layer resubscribes whenever it gets a new stream.
  final Stream<LocationMarkerHeading?> _headingStream =
      headingStreamForDevice();
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
    _stationsVm = context.read<DashboardViewModel>();
    _fillUpsVm = context.read<FillUpViewModel>();
    _nudgesVm = context.read<FillUpNudgeViewModel>();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().listenToStations();
      _startTripsAndNudges();
      _initLocation();
    });
  }

  // Kept so the listeners can be removed in dispose without using context.
  late final DashboardViewModel _stationsVm;
  late final FillUpViewModel _fillUpsVm;
  late final FillUpNudgeViewModel _nudgesVm;

  @override
  void dispose() {
    _stationsVm.removeListener(_syncNudgeStations);
    _fillUpsVm.removeListener(_syncNudgeFillUps);
    _nudgesVm.removeListener(_openNudgedFillUp);
    _searchController.dispose();
    _alignToUser.close();
    super.dispose();
  }

  /// Trip recording and "Did you fill up?" nudges share one location stream.
  Future<void> _startTripsAndNudges() async {
    final trips = context.read<TripViewModel>();
    _stationsVm.addListener(_syncNudgeStations);
    _fillUpsVm.addListener(_syncNudgeFillUps);
    _nudgesVm.addListener(_openNudgedFillUp);
    _syncNudgeStations();
    _syncNudgeFillUps();
    await trips.startMonitoring();
    await _nudgesVm.start(trips.locationUpdates);
    _openNudgedFillUp(); // the app may have been opened from a nudge
  }

  void _syncNudgeStations() =>
      _nudgesVm.updateStations(_stationsVm.nearbyStations);

  void _syncNudgeFillUps() {
    _nudgesVm.updateFillUps(_fillUpsVm.fillUps);
    // The map has no fuel picker, so prices follow the fuel you last bought.
    final fuel = FuelType.values.asNameMap()[_fillUpsVm.latest?.fuelType];
    if (fuel != null) _stationsVm.setFuelType(fuel);
  }

  void _openNudgedFillUp() {
    if (!mounted) return;
    final station = _nudgesVm.takePendingStation();
    if (station != null) showFillUpForm(context, atStation: station);
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
        _mapController.move(LatLng(loc.latitude!, loc.longitude!), 14.0);
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
        _mapController.move(LatLng(loc.latitude!, loc.longitude!), 15.0);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Could not get current location');
      }
    }
  }

  void _onItemTapped(int index) {
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
                      border: Border.all(color: accent.withValues(alpha: 0.20)),
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
                            fontWeight: FontWeight.w700,
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
                            color: AppColors.textMuted,
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
                          fontWeight: FontWeight.w700,
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
                    AppColors.goStrong,
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
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Updated ${formatRelativeTime(station.lastUpdated)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
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
                fontWeight: FontWeight.w700,
                color: price > 0 ? color : AppColors.textMuted,
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
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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
      final dist = _haversineMeters(
        _userLat!,
        _userLng!,
        s.latitude,
        s.longitude,
      );
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
      // IndexedStack keeps each tab alive, so the map keeps its position
      // and the tracker keeps its scroll offset when switching tabs.
      body: IndexedStack(
        index: _selectedIndex,
        // Each tab fills the body. Without this the map tab, a Stack of
        // positioned layers, shrinks to its only sized child (the search row).
        sizing: StackFit.expand,
        children: [
          const SafeArea(bottom: false, child: HomeView()),
          _buildMapTab(scheme),
          const SafeArea(bottom: false, child: ProfileView()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: isCupertino(context)
              ? _buildCupertinoTabBar(scheme)
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  backgroundColor: Colors.white.withValues(alpha: 0.97),
                  indicatorColor: AppColors.surfaceMuted,
                  onDestinationSelected: _onItemTapped,
                  destinations: [
                    for (final tab in _tabs)
                      NavigationDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: tab.label,
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
            child: Row(
              children: [
                Expanded(child: _buildSearchBar(context)),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/report'),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Report'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Consumer<DashboardViewModel>(
            builder: (context, vm, _) => MapBottomControls(
              stationCount: vm.visibleStations.length,
              onShowStations: _openNearbyStations,
              onMyLocation: _goToMyLocation,
              onTrackingStarted: _startFollowingUser,
            ),
          ),
        ),
      ],
    );
  }

  /// Centers on the user and keeps them centered while they move.
  void _startFollowingUser() {
    setState(() => _followUser = true);
    _alignToUser.add(_followZoom);
  }

  Future<void> _openNearbyStations({String query = ''}) async {
    FocusScope.of(context).unfocus();
    final vm = context.read<DashboardViewModel>();
    final station = await showNearbyStationsSheet(
      context,
      cheapestId: _cheapestNearbyId(vm.nearbyStations, vm.fuelType),
      userLat: _userLat,
      userLng: _userLng,
      query: query,
    );
    if (station != null && mounted) _showStationDetail(station);
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
          final markerColor = isCheapest ? AppColors.goStrong : Colors.white;
          final borderColor = isCheapest
              ? AppColors.goStrong
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
                        color: AppColors.goStrong,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CHEAPEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w700,
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
            // Dragging the map means the user wants to look around, so stop
            // pulling the view back to them.
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followUser) {
                setState(() => _followUser = false);
              }
            },
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.pinchZoom |
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
            // OSM credit is shown under the map controls instead of the
            // corner widget, which the floating nav bar would cover.
            CurrentLocationLayer(
              headingStream: _headingStream,
              alignPositionStream: _alignToUser.stream,
              alignPositionOnUpdate: _followUser
                  ? AlignOnUpdate.always
                  : AlignOnUpdate.never,
              style: LocationMarkerStyle(
                marker: const DefaultLocationMarker(
                  color: Color(0xFF2563EB),
                  child: Icon(Icons.circle, color: Colors.white, size: 12),
                ),
                markerSize: const Size.square(24),
                accuracyCircleColor: const Color(
                  0xFF2563EB,
                ).withValues(alpha: 0.08),
                headingSectorColor: const Color(
                  0xFF2563EB,
                ).withValues(alpha: 0.30),
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
      onSubmitted: (q) => _openNearbyStations(query: q),
    );
  }

  Widget _buildCupertinoSearchBar(BuildContext context) {
    return CupertinoTextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      placeholder: 'Search station, brand, area',
      placeholderStyle: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: AppColors.textMuted,
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
        child: Icon(Icons.search, color: AppColors.textMuted),
      ),
      suffix: _searchController.text.isNotEmpty
          ? AppIconButton(
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.close, color: AppColors.textMuted),
              tooltip: 'Clear',
            )
          : null,
      onSubmitted: (q) => _openNearbyStations(query: q),
    );
  }

  Widget _buildCupertinoTabBar(ColorScheme scheme) {
    return CupertinoTabBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      border: null,
      activeColor: scheme.primary,
      inactiveColor: scheme.onSurfaceVariant,
      items: [
        for (final tab in _tabs)
          BottomNavigationBarItem(
            icon: Icon(tab.icon),
            activeIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
      ],
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
