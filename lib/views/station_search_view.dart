import 'package:flutter/material.dart';

import '../components/app_empty_state.dart';
import '../components/brand_logo.dart';
import '../models/station_model.dart';
import '../models/station_search.dart';
import '../services/recent_searches.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_page_route.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'nearby_stations_sheet.dart';

/// Opens the full-screen station search. Resolves to the station the user
/// picked, or null if they went back.
Future<StationModel?> showStationSearch(
  BuildContext context, {
  required List<StationModel> stations,
  required FuelType fuelType,
  double? userLat,
  double? userLng,
  RecentSearches? recent,
}) {
  return Navigator.push<StationModel>(
    context,
    appRoute<StationModel>(
      context,
      (_) => StationSearchView(
        stations: stations,
        fuelType: fuelType,
        userLat: userLat,
        userLng: userLng,
        recent: recent,
      ),
      fullscreenDialog: true,
    ),
  );
}

/// Maps-style search: a field that has the keyboard up at once, a row of
/// quick chips (the brands around you), your recent searches, and every
/// station nearest-first. Typing narrows the list as you go.
class StationSearchView extends StatefulWidget {
  final List<StationModel> stations;
  final FuelType fuelType;
  final double? userLat;
  final double? userLng;
  final RecentSearches? recent;

  const StationSearchView({
    super.key,
    required this.stations,
    required this.fuelType,
    this.userLat,
    this.userLng,
    this.recent,
  });

  @override
  State<StationSearchView> createState() => _StationSearchViewState();
}

class _StationSearchViewState extends State<StationSearchView> {
  final _controller = TextEditingController();
  late final RecentSearches _recent = widget.recent ?? RecentSearches();
  List<String> _recentQueries = const [];
  final Set<StationFilter> _filters = {};

  String get _query => _controller.text.trim();
  bool get _hasFix => widget.userLat != null && widget.userLng != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _recent.load().then((list) {
      if (mounted) setState(() => _recentQueries = list);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
  }

  Future<void> _remember(String q) async {
    if (q.trim().isEmpty) return;
    final list = await _recent.add(q);
    if (mounted) setState(() => _recentQueries = list);
  }

  Future<void> _forget(String q) async {
    final list = await _recent.remove(q);
    if (mounted) setState(() => _recentQueries = list);
  }

  void _pick(StationModel station) {
    _remember(_query);
    Navigator.pop(context, station);
  }

  double _priceOf(StationModel s) => switch (widget.fuelType) {
    FuelType.regular => s.regularPrice,
    FuelType.premium => s.premiumPrice,
    FuelType.diesel => s.dieselPrice,
  };

  @override
  Widget build(BuildContext context) {
    final ordered = nearestFirst(
      widget.stations,
      userLat: widget.userLat,
      userLng: widget.userLng,
    );
    final results = applyFilters(filterStations(ordered, _query), _filters);
    final brands = brandsAmong(widget.stations);
    final isFiltering = _query.isNotEmpty || _filters.isNotEmpty;
    final showRecent = !isFiltering && _recentQueries.isNotEmpty;
    final heading = isFiltering
        ? '${results.length} ${results.length == 1 ? 'result' : 'results'}'
        : _hasFix
        ? 'Nearest to you'
        : 'All stations';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchField(
              controller: _controller,
              onSubmitted: _remember,
              onClear: () => _setQuery(''),
            ),
            _QuickChips(
              brands: brands,
              selectedBrand: _query,
              filters: _filters,
              onBrand: (b) =>
                  _setQuery(_query.toLowerCase() == b.toLowerCase() ? '' : b),
              onFilter: (f) => setState(() {
                if (!_filters.remove(f)) _filters.add(f);
              }),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (showRecent) ...[
                    const _Heading('Recent'),
                    for (final q in _recentQueries)
                      _RecentRow(
                        query: q,
                        onTap: () => _setQuery(q),
                        onRemove: () => _forget(q),
                      ),
                    const SizedBox(height: 8),
                  ],
                  _Heading(heading),
                  if (results.isEmpty)
                    AppEmptyState(
                      icon: Icons.local_gas_station_outlined,
                      title: !isFiltering
                          ? 'No stations yet'
                          : _query.isEmpty
                          ? 'No stations match'
                          : 'No stations match "$_query"',
                      subtitle: !isFiltering
                          ? 'Stations appear here once they are added.'
                          : _filters.isNotEmpty
                          ? 'No station nearby lists all of those.'
                          : 'Try a brand, a station name or an area.',
                    )
                  else
                    for (final s in results) ...[
                      StationRow(
                        station: s,
                        price: _priceOf(s),
                        fuelLabel: fuelTypeLabels[widget.fuelType]!,
                        isCheapest: false,
                        distance: switch (distanceToStation(
                          s,
                          widget.userLat,
                          widget.userLng,
                        )) {
                          final m? => formatDistance(m),
                          null => null,
                        },
                        onTap: () => _pick(s),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          AppIconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search station, brand, area',
                suffixIcon: controller.text.isNotEmpty
                    ? AppIconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: onClear,
                      )
                    : null,
              ),
              onSubmitted: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick picks like a maps app's Home and Work, but for fuel: what a
/// station offers (restroom, 24 hours, store, …) first, then one chip per
/// brand reported around you, most common first.
class _QuickChips extends StatelessWidget {
  final List<String> brands;
  final String selectedBrand;
  final Set<StationFilter> filters;
  final ValueChanged<String> onBrand;
  final ValueChanged<StationFilter> onFilter;

  const _QuickChips({
    required this.brands,
    required this.selectedBrand,
    required this.filters,
    required this.onBrand,
    required this.onFilter,
  });

  static const _filterIcons = {
    StationFilter.restroom: Icons.wc_outlined,
    StationFilter.open24Hours: Icons.schedule_outlined,
    StationFilter.convenienceStore: Icons.storefront_outlined,
    StationFilter.airPump: Icons.tire_repair_outlined,
    StationFilter.carWash: Icons.local_car_wash_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final f in StationFilter.values)
        _Chip(
          label: f.label,
          selected: filters.contains(f),
          leading: Icon(
            _filterIcons[f],
            size: 18,
            color: filters.contains(f) ? Colors.white : AppColors.ink,
          ),
          onTap: () => onFilter(f),
        ),
      for (final b in brands)
        _Chip(
          label: b,
          selected: b.toLowerCase() == selectedBrand.toLowerCase(),
          leading: Container(
            width: 26,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: brandLogoWidget(b, 20),
          ),
          onTap: () => onBrand(b),
        ),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.ink : AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: AppTappable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.text,
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

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentRow({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.history, size: 20, color: AppColors.textMuted),
            ),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: AppColors.text),
              ),
            ),
            AppIconButton(
              tooltip: 'Remove $query from recent searches',
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textMuted,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
