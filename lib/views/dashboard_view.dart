import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
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
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/map_style.dart';
import '../components/brand_logo.dart';
import '../components/map_bottom_controls.dart';
import '../services/geo.dart';
import '../services/heading_stream.dart';
import '../models/map_framing.dart';
import 'nearby_stations_sheet.dart';
import 'station_detail_sheet.dart';
import 'home_view.dart';
import 'profile_view.dart';
import 'tracking_disclosure_sheet.dart';

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
const _locationTimeout = Duration(seconds: 8);

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
  bool _didFrameStations = false;
  bool _locationResolved = false;

  /// Created once: the layer resubscribes whenever it gets a new stream.
  /// The compass needs no permission.
  final Stream<LocationMarkerHeading?> _headingStream =
      headingStreamForDevice();

  /// The blue dot's positions. It never asks for permission itself (the
  /// tracking disclosure must come first), and it closes for good if
  /// location isn't allowed yet, so it is recreated once permission is
  /// confirmed; see [_onLocationAllowed].
  Stream<LocationMarkerPosition?> _positionStream = _newPositionStream();
  bool _positionStreamHasPermission = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<DashboardViewModel>().listenToStations();
      // Signed in by now: pull this account's fill-ups from the cloud.
      _fillUpsVm.load();
      // Explain background tracking before any location prompt appears.
      await _askAboutAutoTracking();
      if (!mounted) return;
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

  /// Starts automatic tracking if allowed earlier; otherwise shows the
  /// disclosure once and saves the answer.
  Future<void> _askAboutAutoTracking() async {
    final trips = context.read<TripViewModel>();
    await trips.startAutoTracking();
    if (trips.autoTrackingChoice != null || !mounted) return;
    final allowed = await showTrackingDisclosure(context);
    // Dismissed without an answer: ask again next time.
    if (allowed != null) await trips.setAutoTracking(allowed);
  }

  /// Trip recording and "Did you fill up?" nudges share one location stream,
  /// which only runs while automatic tracking is on.
  Future<void> _startTripsAndNudges() async {
    final trips = context.read<TripViewModel>();
    _stationsVm.addListener(_syncNudgeStations);
    _fillUpsVm.addListener(_syncNudgeFillUps);
    _nudgesVm.addListener(_openNudgedFillUp);
    _syncNudgeStations();
    _syncNudgeFillUps();
    await _nudgesVm.start(trips.locationUpdates);
    _openNudgedFillUp(); // the app may have been opened from a nudge
  }

  void _syncNudgeStations() {
    _nudgesVm.updateStations(_stationsVm.nearbyStations);
    _frameStationsOnce();
  }

  /// On first open, fit the reported stations in view (see [pointsToFrame])
  /// once stations have loaded and the location lookup has finished.
  void _frameStationsOnce() {
    if (_didFrameStations || !_locationResolved || _stationsVm.isLoading) {
      return;
    }
    final points = pointsToFrame(
      _stationsVm.visibleStations,
      userLat: _userLat,
      userLng: _userLng,
    );
    if (points.isEmpty) return;
    _didFrameStations = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coords = [for (final (lat, lng) in points) LatLng(lat, lng)];
      if (coords.length == 1) {
        _mapController.move(coords.single, 15);
        return;
      }
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coords,
          // Clear the search row on top and the controls at the bottom.
          padding: const EdgeInsets.fromLTRB(48, 160, 48, 300),
          maxZoom: 15,
        ),
      );
    });
  }

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
    try {
      await _lookUpInitialLocation();
    } finally {
      _locationResolved = true;
      _frameStationsOnce();
    }
  }

  static Stream<LocationMarkerPosition?> _newPositionStream() {
    const factory = LocationMarkerDataStreamFactory();
    return factory.fromGeolocatorPositionStream(
      stream: factory.defaultPositionStreamSource(
        requestPermissionCallback: null,
      ),
    );
  }

  /// Location is allowed now: give the dot a fresh stream if the current
  /// one started (and closed) before permission was granted.
  void _onLocationAllowed() {
    if (_positionStreamHasPermission || !mounted) return;
    setState(() {
      _positionStreamHasPermission = true;
      _positionStream = _newPositionStream();
    });
  }

  /// Turns on location and asks for permission if needed. True when allowed.
  Future<bool> _ensureLocationAllowed() async {
    try {
      var serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;

      var permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      final allowed =
          permission == PermissionStatus.granted ||
          permission == PermissionStatus.grantedLimited;
      if (allowed) _onLocationAllowed();
      return allowed;
    } on PlatformException catch (e) {
      debugPrint('Location permission check failed: ${e.code}');
      return false;
    }
  }

  Future<void> _lookUpInitialLocation() async {
    if (!await _ensureLocationAllowed()) return;

    try {
      final loc = await _location.getLocation().timeout(_locationTimeout);
      if (loc.latitude != null && loc.longitude != null && mounted) {
        setState(() {
          _userLat = loc.latitude;
          _userLng = loc.longitude;
        });
        _mapController.move(LatLng(loc.latitude!, loc.longitude!), 14.0);
      }
    } on TimeoutException {
      debugPrint('Initial location lookup timed out');
    } on PlatformException catch (e) {
      debugPrint('Initial location lookup failed: ${e.code}');
    }
  }

  /// Re-centres on the user. The location dot's own fix answers at once;
  /// the plugin lookup (which can wait forever without a GPS fix) is capped.
  Future<void> _goToMyLocation() async {
    if (!await _ensureLocationAllowed()) {
      if (mounted) {
        showAppToast(context, 'Allow location access to see where you are.');
      }
      return;
    }
    _alignToUser.add(15);
    try {
      final loc = await _location.getLocation().timeout(_locationTimeout);
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat == null || lng == null || !mounted) return;
      setState(() {
        _userLat = lat;
        _userLng = lng;
      });
      _mapController.move(LatLng(lat, lng), 15.0);
    } on TimeoutException {
      if (mounted) {
        showAppToast(
          context,
          "Can't find your location yet. Check that location is on.",
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Location lookup failed: ${e.code}');
      if (mounted) {
        showAppToast(context, 'Allow location access to see where you are.');
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showStationDetail(StationModel station) {
    // (0,0) means no coordinates; moving there would show open ocean.
    if (station.latitude != 0 || station.longitude != 0) {
      _mapController.move(LatLng(station.latitude, station.longitude), 16.0);
    }
    showStationDetailSheet(
      context,
      station: station,
      userLat: _userLat,
      userLng: _userLng,
      onReport: () => Navigator.pushNamed(context, '/report'),
    );
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
      final dist = haversineMeters(
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
              onTrackingStopped: _stopFollowingUser,
            ),
          ),
        ),
      ],
    );
  }

  /// Centers on the user and keeps them centered while they move.
  void _startFollowingUser() {
    _onLocationAllowed(); // tracking started, so location is allowed
    setState(() => _followUser = true);
    _alignToUser.add(_followZoom);
  }

  /// Tracking stopped by hand: let the map rest where it is.
  void _stopFollowingUser() {
    if (!mounted || !_followUser) return;
    setState(() => _followUser = false);
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
        // Markers follow the "With prices" filter, like the list does.
        final stations = vm.visibleStations;
        final cheapestId = _cheapestNearbyId(stations, vm.fuelType);
        final markers = stations.map((s) {
          final price = switch (vm.fuelType) {
            FuelType.regular => s.regularPrice,
            FuelType.premium => s.premiumPrice,
            FuelType.diesel => s.dieselPrice,
          };
          final isCheapest = s.id == cheapestId;
          // Black and white: white pills, the cheapest one inverted.
          final markerColor = isCheapest ? AppColors.ink : Colors.white;
          final borderColor = isCheapest ? AppColors.ink : AppColors.divider;
          final textColor = isCheapest ? Colors.white : AppColors.ink;
          return Marker(
            point: LatLng(s.latitude, s.longitude),
            width: 170,
            height: isCheapest ? 86 : 68,
            // The box sits above the point, so the pointer's tip marks it.
            alignment: Alignment.topCenter,
            child: Semantics(
              button: true,
              label:
                  '${s.displayName}, ${formatPricePerLiter(price)}'
                  '${isCheapest ? ', cheapest nearby' : ''}',
              excludeSemantics: true,
              onTap: () => _showStationDetail(s),
              child: GestureDetector(
                onTap: () => _showStationDetail(s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isCheapest)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.ink),
                        ),
                        child: const Text(
                          'Cheapest',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                      decoration: BoxDecoration(
                        color: markerColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x29000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: brandLogoWidget(
                              s.brand,
                              18,
                              stationName: s.name,
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
              userAgentPackageName: 'com.maalam.gasolinahan',
              tileBuilder: monochromeTileBuilder,
            ),
            // OSM credit is shown under the map controls instead of the
            // corner widget, which the floating nav bar would cover.
            CurrentLocationLayer(
              positionStream: _positionStream,
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
                      color: AppColors.ink,
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
