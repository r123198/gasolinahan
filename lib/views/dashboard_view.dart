import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' show Style;
import '../models/app_access.dart';
import '../models/station_model.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/fill_up_nudge_viewmodel.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import 'fill_up_form_sheet.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';
import '../ui/map_style.dart';
import '../ui/web_layout.dart';
import '../components/guest_map_bar.dart';
import '../components/map_bottom_controls.dart';
import '../components/station_marker.dart';
import '../services/app_links.dart';
import '../services/current_location.dart';
import '../services/geo.dart';
import '../services/heading_stream.dart';
import '../models/map_framing.dart';
import 'nearby_stations_sheet.dart';
import 'station_detail_sheet.dart';
import 'station_search_view.dart';
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

/// Zoom used when centering on the user while a trip is being followed.
const _followZoom = 16.0;

/// Street-level zoom used when the map opens on the user or they tap
/// my-location: a few blocks, close enough to tell stations apart.
const _closeZoom = 17.0;
const _locationTimeout = Duration(seconds: 8);

/// A mouse wheel is how a desktop browser zooms a map; on the phones a
/// wheel never comes up, so their gestures are unchanged.
const _mapGestures =
    InteractiveFlag.pinchZoom |
    InteractiveFlag.drag |
    InteractiveFlag.flingAnimation |
    InteractiveFlag.doubleTapZoom |
    (kIsWeb ? InteractiveFlag.scrollWheelZoom : InteractiveFlag.none);

class DashboardView extends StatefulWidget {
  /// What signing in was for, when that's what brought the user here.
  final SignInGoal? goal;

  const DashboardView({super.key, this.goal});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late int _selectedIndex = initialDashboardTab(
    isWeb: kIsWeb,
    goal: widget.goal,
  );

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

  /// Fetched once; the map shows the vector basemap when it arrives.
  late final Future<Style> _basemapStyle = readBasemapStyle();

  // Default center: Metro Manila (Makati area)
  static const _defaultCenter = LatLng(14.5648, 121.0453);
  static const _defaultZoom = 13.0;

  // User location for distance calculations
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _stationsVm = context.read<DashboardViewModel>();
    _fillUpsVm = context.read<FillUpViewModel>();
    _nudgesVm = context.read<FillUpNudgeViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<DashboardViewModel>().listenToStations();
      // Signed in by now: pull this account's fill-ups from the cloud.
      if (!_isGuest) _fillUpsVm.load();
      // Explain background tracking before any location prompt appears.
      // Browsers can't track in the background, so they never ask.
      if (!kIsWeb) await _askAboutAutoTracking();
      if (!mounted) return;
      _startTripsAndNudges();
      _initLocation();
    });
  }

  bool get _isGuest => isGuestVisitor(
    isWeb: kIsWeb,
    isSignedIn: context.read<AuthViewModel>().isAuthenticated,
  );

  // Kept so the listeners can be removed in dispose without using context.
  late final DashboardViewModel _stationsVm;
  late final FillUpViewModel _fillUpsVm;
  late final FillUpNudgeViewModel _nudgesVm;

  @override
  void dispose() {
    _stationsVm.removeListener(_syncNudgeStations);
    _fillUpsVm.removeListener(_syncNudgeFillUps);
    _nudgesVm.removeListener(_openNudgedFillUp);
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
    if (kIsWeb) return; // nudges need trips, which browsers don't record
    await _nudgesVm.start(trips.locationUpdates);
    _openNudgedFillUp(); // the app may have been opened from a nudge
  }

  void _syncNudgeStations() {
    _nudgesVm.updateStations(_stationsVm.nearbyStations);
    _frameStationsOnce();
  }

  /// On first open, once stations have loaded and the location lookup has
  /// finished: with a fix the map stays close in on the user (see
  /// [_lookUpInitialLocation]); without one it fits the reported stations
  /// (see [pointsToFrame]) so it never opens on empty sea.
  void _frameStationsOnce() {
    if (_didFrameStations || !_locationResolved || _stationsVm.isLoading) {
      return;
    }
    if (_userLat != null && _userLng != null) {
      _didFrameStations = true;
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
          // Clear the status bar on top and the controls at the bottom.
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 300),
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
    if (kIsWeb) {
      final allowed = await askBrowserForLocation();
      if (allowed) _onLocationAllowed();
      return allowed;
    }
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
    // A prompt on a page someone just opened gets refused, and browsers
    // remember that; ask when they tap my-location instead.
    if (kIsWeb && !await isLocationAllowedInBrowser()) return;
    if (!await _ensureLocationAllowed()) return;
    // A recent cached fix centres the map at once; a fresh one refines it.
    final cached = await readLastKnownLocation();
    if (cached != null) _showUserAt(cached, zoom: _closeZoom);
    final fix = await readCurrentLocation(timeout: _locationTimeout);
    if (fix == null) {
      debugPrint('Initial location lookup found no fix');
      return;
    }
    _showUserAt(fix, zoom: _closeZoom);
  }

  /// Re-centres on the user: the cached fix answers at once, then a fresh
  /// reading (capped, so a missing GPS fix can't leave the button hanging).
  Future<void> _goToMyLocation() async {
    if (!await _ensureLocationAllowed()) {
      if (mounted) {
        showAppToast(context, 'Allow location access to see where you are.');
      }
      return;
    }
    _alignToUser.add(_closeZoom);
    final cached = await readLastKnownLocation();
    if (cached != null) _showUserAt(cached, zoom: _closeZoom);
    final fix = await readCurrentLocation(timeout: _locationTimeout);
    if (fix != null) {
      _showUserAt(fix, zoom: _closeZoom);
      return;
    }
    if (cached == null && mounted) {
      showAppToast(
        context,
        "Can't find your location yet. Check that location is on.",
      );
    }
  }

  /// Remembers where the user is (for distances) and moves the map there.
  void _showUserAt(GeoFix fix, {required double zoom}) {
    if (!mounted) return;
    setState(() {
      _userLat = fix.latitude;
      _userLng = fix.longitude;
    });
    _mapController.move(LatLng(fix.latitude, fix.longitude), zoom);
  }

  /// Sends a guest to sign in, carrying on with [goal] afterwards.
  void _askGuestToSignIn([SignInGoal? goal]) {
    Navigator.pushNamed(context, '/login', arguments: goal);
  }

  /// How the map offers reporting. Null on the web, whose map is read-only:
  /// prices are only reported from the phone apps.
  VoidCallback? get _reportAction =>
      kIsWeb ? null : () => Navigator.pushNamed(context, '/report');

  void _onItemTapped(int index) {
    final goal = signInGoalForTab(index);
    if (_isGuest && goal != null) {
      _askGuestToSignIn(goal);
      return;
    }
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
      onReport: _reportAction,
      loadDetails: _stationsVm.loadDetails,
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
    final isGuest = isGuestVisitor(
      isWeb: kIsWeb,
      isSignedIn: context.select<AuthViewModel, bool>(
        (auth) => auth.isAuthenticated,
      ),
    );
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF4F6F9),
      // IndexedStack keeps each tab alive, so the map keeps its position
      // and the tracker keeps its scroll offset when switching tabs.
      body: IndexedStack(
        index: _selectedIndex,
        // Each tab fills the body. Without this the map tab, a Stack of
        // positioned layers, shrinks to its only sized child.
        sizing: StackFit.expand,
        children: [
          if (isGuest)
            const SizedBox.shrink()
          else
            const WebWidthLimit(
              maxWidth: webTabMaxWidth,
              child: SafeArea(bottom: false, child: HomeView()),
            ),
          _buildMapTab(scheme, isGuest: isGuest),
          if (isGuest)
            const SizedBox.shrink()
          else
            const WebWidthLimit(
              maxWidth: webTabMaxWidth,
              child: SafeArea(bottom: false, child: ProfileView()),
            ),
        ],
      ),
      bottomNavigationBar: WebWidthLimit(
        maxWidth: webNavMaxWidth,
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Padding(
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
      ),
    );
  }

  Widget _buildMapTab(ColorScheme scheme, {required bool isGuest}) {
    return Stack(
      children: [
        Positioned.fill(child: _buildMap()),
        Positioned(
          left: 16,
          right: 16,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isGuest)
                    GuestMapBar(
                      onAbout: () => openLink(aboutUrl),
                      onSignIn: _askGuestToSignIn,
                    ),
                  const _MapLoadError(),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: WebWidthLimit(
            maxWidth: webMapControlsMaxWidth,
            alignment: Alignment.bottomRight,
            child: Consumer<DashboardViewModel>(
              builder: (context, vm, _) => MapBottomControls(
                stationCount: vm.visibleStations.length,
                onShowStations: _openNearbyStations,
                onSearch: _openSearch,
                onReport: _reportAction,
                onMyLocation: _goToMyLocation,
                onTrackingStarted: _startFollowingUser,
                onTrackingStopped: _stopFollowingUser,
              ),
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

  Future<void> _openNearbyStations() async {
    final vm = context.read<DashboardViewModel>();
    final station = await showNearbyStationsSheet(
      context,
      cheapestId: _cheapestNearbyId(vm.nearbyStations, vm.fuelType),
      userLat: _userLat,
      userLng: _userLng,
    );
    if (station != null && mounted) _showStationDetail(station);
  }

  /// Full-screen search over every reported station, nearest first.
  Future<void> _openSearch() async {
    final vm = context.read<DashboardViewModel>();
    final station = await showStationSearch(
      context,
      stations: vm.nearbyStations,
      fuelType: vm.fuelType,
      userLat: _userLat,
      userLng: _userLng,
    );
    if (station != null && mounted) _showStationDetail(station);
  }

  Marker _marker(StationModel s, {required double price, PriceTier? tier}) {
    final size = stationMarkerSize(
      hasPrice: tier != null,
      isCheapest: tier == PriceTier.cheapest,
    );
    return Marker(
      point: LatLng(s.latitude, s.longitude),
      width: size.width,
      height: size.height,
      // The box sits above the point, so the pointer's tip marks it.
      alignment: Alignment.topCenter,
      child: StationMarker(
        station: s,
        price: price,
        tier: tier,
        onTap: () => _showStationDetail(s),
      ),
    );
  }

  Widget _buildMap() {
    return Consumer<DashboardViewModel>(
      builder: (context, vm, _) {
        // Markers follow the "With prices" filter, like the list does.
        final stations = vm.visibleStations;
        final cheapestId = _cheapestNearbyId(stations, vm.fuelType);
        double priceOf(StationModel s) => switch (vm.fuelType) {
          FuelType.regular => s.regularPrice,
          FuelType.premium => s.premiumPrice,
          FuelType.diesel => s.dieselPrice,
        };
        // Price tiers are coloured against the cheapest price on the map.
        final priced = [
          for (final s in stations)
            if (priceOf(s) > 0) priceOf(s),
        ];
        final cheapest = priced.isEmpty
            ? 0.0
            : priced.reduce((a, b) => a < b ? a : b);
        final markers = [
          for (final s in stations)
            if (s.isPlaced)
              _marker(
                s,
                price: priceOf(s),
                tier: priceOf(s) <= 0
                    ? null
                    : s.id == cheapestId
                    ? PriceTier.cheapest
                    : priceTierOf(priceOf(s), cheapest),
              ),
        ];

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
            interactionOptions: const InteractionOptions(flags: _mapGestures),
          ),
          children: [
            // See map_style.dart: OpenFreeMap Positron, or plain OSM tiles
            // if the style can't be fetched.
            FutureBuilder<Style>(future: _basemapStyle, builder: basemapLayer),
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

/// Says so when the stations can't load, instead of an empty map that looks
/// like there's no data. The web's landing page depends on this read.
class _MapLoadError extends StatelessWidget {
  const _MapLoadError();

  @override
  Widget build(BuildContext context) {
    final message = context.select<DashboardViewModel, String?>(
      (vm) => vm.errorMessage,
    );
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: context.read<DashboardViewModel>().listenToStations,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
