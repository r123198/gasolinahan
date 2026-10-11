import 'package:flutter/material.dart';

import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import 'track_me_button.dart';

const _shadow = [
  BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
];

/// Controls along the bottom of the map, above the nav bar: Track me and
/// my-location on one row, the "Nearby stations" bar below, then the map
/// data credit OpenStreetMap requires.
class MapBottomControls extends StatelessWidget {
  final int stationCount;
  final VoidCallback onShowStations;
  final VoidCallback onMyLocation;
  final VoidCallback onTrackingStarted;
  final VoidCallback? onTrackingStopped;

  const MapBottomControls({
    super.key,
    required this.stationCount,
    required this.onShowStations,
    required this.onMyLocation,
    required this.onTrackingStarted,
    this.onTrackingStopped,
  });

  @override
  Widget build(BuildContext context) {
    // extendBody gives the body a bottom padding equal to the nav bar.
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TrackMeButton(
                    onStarted: onTrackingStarted,
                    onStopped: onTrackingStopped,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: _shadow,
                ),
                child: AppIconButton(
                  tooltip: 'Go to my location',
                  padding: const EdgeInsets.all(14),
                  icon: const Icon(
                    Icons.my_location,
                    size: 24,
                    color: AppColors.ink,
                  ),
                  onPressed: onMyLocation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NearbyBar(count: stationCount, onTap: onShowStations),
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyBar extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NearbyBar({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Show $count nearby stations',
      // excludeSemantics hides the InkWell's action, so declare it here.
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _shadow,
        ),
        child: AppTappable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.local_gas_station_outlined,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Nearby stations',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_up, color: AppColors.textMuted),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
