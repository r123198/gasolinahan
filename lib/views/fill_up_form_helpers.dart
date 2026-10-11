part of 'fill_up_form_sheet.dart';

/// Lookups and builders for the fill-up form that don't change state on
/// their own (callers wrap them in setState). Split out to keep the form
/// file readable.
extension _FillUpFormHelpers on _FillUpFormState {
  /// Recent stations first (where people usually refill), then nearby ones.
  List<StationChoice> _buildChoices() {
    final seen = <StationChoice>{};
    // summarize() already orders stations by most recent visit.
    final recent = context.read<FillUpViewModel>().summaries;
    final nearby = context.read<DashboardViewModel>().nearbyStations;
    return [
      for (final s in recent)
        if (seen.add(StationChoice(s.stationId, s.stationName, s.brand)))
          StationChoice(s.stationId, s.stationName, s.brand),
      for (final s in nearby)
        // Stations saved without a name come back as "Unknown Station";
        // the brand logos below are the better way to pick those.
        if (s.name.trim().isNotEmpty &&
            s.name != 'Unknown Station' &&
            seen.add(StationChoice(s.id, s.name, s.brand)))
          StationChoice(s.id, s.name, s.brand),
    ];
  }

  /// Fills price per liter from the station's reported price, else the last
  /// price paid there, unless the user has typed their own.
  void _prefillPrice() {
    if (_priceEditedByUser) return;
    final station = _station;
    final brand = _brand;
    double? price;
    if (brand != null) price = _nearbyPriceForBrand(brand);
    if (station != null && station.id.isNotEmpty) {
      final reported = context
          .read<DashboardViewModel>()
          .nearbyStations
          .where((s) => s.id == station.id)
          .map(
            (s) =>
                // The exact product's reported price beats the grade's.
                s.productPrices[_product?.name] ??
                switch (_fuel) {
                  FuelType.regular => s.regularPrice,
                  FuelType.premium => s.premiumPrice,
                  FuelType.diesel => s.dieselPrice,
                },
          )
          .firstOrNull;
      price = (reported != null && reported > 0)
          ? reported
          : context.read<FillUpViewModel>().lastPriceAt(station.id, _fuel.name);
    }
    final text = price?.toStringAsFixed(2) ?? '';
    if (_priceCtrl.text != text) {
      _priceCtrl.removeListener(_onEdited);
      _priceCtrl.text = text;
      _priceCtrl.addListener(_onEdited);
    }
  }

  /// A nearby station of [brand] that has a reported price for this fuel.
  double? _nearbyPriceForBrand(BrandInfo brand) {
    for (final s in context.read<DashboardViewModel>().nearbyStations) {
      final match = BrandRegistry.match(s.brand, stationName: s.name);
      if (match?.name != brand.name) continue;
      final price = switch (_fuel) {
        FuelType.regular => s.regularPrice,
        FuelType.premium => s.premiumPrice,
        FuelType.diesel => s.dieselPrice,
      };
      if (price > 0) return price;
    }
    return null;
  }

  /// The product last bought at [brand], else its first of the current grade.
  FuelProduct? _defaultProduct(BrandInfo? brand) {
    if (brand == null) return null;
    final last = context
        .read<FillUpViewModel>()
        .fillUps
        .where(
          (f) =>
              f.productName != null &&
              BrandRegistry.match(f.brand, stationName: f.stationName)?.name ==
                  brand.name,
        )
        .firstOrNull;
    final remembered = brand.productNamed(last?.productName ?? '');
    if (remembered != null) return remembered;
    final grade = FuelCategory.values.byName(_fuel.name);
    return brand.byCategory(grade).firstOrNull;
  }

  /// Keeps the saved grade in step with a remembered product, so a Petron
  /// XCS pick isn't stored (and priced) as last time's diesel.
  void _matchFuelToProduct() {
    final product = _product;
    if (product != null) _fuel = FuelType.values.byName(product.category.name);
  }

  /// Puts the looked-up area into an empty branch field.
  void _fillBranchFromArea() {
    final area = _suggestedArea;
    if (_brand != null && area != null && _nameCtrl.text.trim().isEmpty) {
      _setAutoBranch(area);
    }
  }

  void _setAutoBranch(String text) {
    _nameCtrl.removeListener(_onEdited);
    _nameCtrl.text = text;
    _nameCtrl.addListener(_onEdited);
    _autoBranch = text;
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffixText,
    String? error,
    String? helper,
    bool decimal = true,
    bool autofocus = false,
    TextInputAction action = TextInputAction.next,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: action,
      onChanged: onChanged,
      onSubmitted: action == TextInputAction.done ? (_) => _save() : null,
      inputFormatters: [numberInputFormatter(decimal: decimal)],
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        errorText: error,
        errorMaxLines: 3,
        helperText: helper,
      ),
    );
  }
}
