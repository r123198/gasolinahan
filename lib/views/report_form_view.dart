import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_circle_button.dart';
import '../components/app_form_error.dart';
import '../components/app_primary_button.dart';
import '../models/brand_registry.dart';
import '../models/fill_up_validator.dart' show parseNumber;
import '../models/report_validator.dart';
import '../models/station_model.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';
import '../viewmodels/report_viewmodel.dart';
import 'fill_up_form_parts.dart' show BrandChips, FieldError;
import 'report_form_parts.dart';
import '../components/report_price_row.dart';

class ReportFormView extends StatefulWidget {
  const ReportFormView({super.key});

  @override
  State<ReportFormView> createState() => _ReportFormViewState();
}

class _ReportFormViewState extends State<ReportFormView> {
  late TextEditingController _regularCtrl;
  late TextEditingController _premiumCtrl;
  late TextEditingController _dieselCtrl;
  BrandInfo? _selectedBrand;

  /// "Other" in the brand row: an independent station, so show them all.
  bool _otherBrand = false;
  StationModel? _selectedStation;
  bool _submitted = false;
  String? _brandError;
  String? _stationError;
  String? _formError;
  ReportPriceErrors _priceErrors = const ReportPriceErrors();

  /// Checks the form and stores the inline errors; true when it can submit.
  bool _validateForm() {
    _brandError = _selectedBrand == null && !_otherBrand
        ? 'Choose the station brand'
        : null;
    _stationError = _selectedStation == null ? 'Choose the station' : null;
    _priceErrors = validateReportPrices(
      regular: _regularCtrl.text,
      premium: _premiumCtrl.text,
      diesel: _dieselCtrl.text,
    );
    return _brandError == null && _stationError == null && _priceErrors.isEmpty;
  }

  /// After the first submit attempt, errors clear as fields get fixed.
  void _revalidate() {
    if (_submitted) setState(_validateForm);
  }

  @override
  void initState() {
    super.initState();
    final vm = context.read<ReportViewModel>();
    _regularCtrl = TextEditingController(text: _formatPrice(vm.regularPrice));
    _premiumCtrl = TextEditingController(text: _formatPrice(vm.premiumPrice));
    _dieselCtrl = TextEditingController(text: _formatPrice(vm.dieselPrice));

    // Auto-select brand from OCR detection
    _selectedBrand = vm.detectedBrand ?? BrandRegistry.findByName(vm.brand);

    // Auto-select station if matched by proximity
    if (vm.matchedStation != null) {
      _selectedStation = vm.matchedStation;
      _selectedBrand ??= BrandRegistry.findByName(vm.matchedStation!.brand);
    }
  }

  String _formatPrice(double price) {
    if (price <= 0) return '';
    return price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _regularCtrl.dispose();
    _premiumCtrl.dispose();
    _dieselCtrl.dispose();
    super.dispose();
  }

  // Product label for a fuel category based on selected brand
  String _productLabel(FuelCategory category) {
    if (_selectedBrand == null) {
      return switch (category) {
        FuelCategory.regular => 'Regular',
        FuelCategory.premium => 'Premium',
        FuelCategory.diesel => 'Diesel',
      };
    }
    final product = switch (category) {
      FuelCategory.regular => _selectedBrand!.regularProduct,
      FuelCategory.premium => _selectedBrand!.premiumProduct,
      FuelCategory.diesel => _selectedBrand!.dieselProduct,
    };
    return product?.name ??
        switch (category) {
          FuelCategory.regular => 'Regular',
          FuelCategory.premium => 'Premium',
          FuelCategory.diesel => 'Diesel',
        };
  }

  /// Back (button or system gesture) would throw away the photo, the
  /// scanned prices and any edits, so ask first.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final discard = await showAppConfirmDialog(
      context: context,
      title: 'Discard this report?',
      message: 'Your photo and the prices you entered will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      isDestructive: true,
    );
    if (!discard || !mounted) return;
    context.read<ReportViewModel>().reset();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: _buildScaffold(context),
    );
  }

  void _selectBrand(BrandInfo brand) {
    setState(() {
      _selectedBrand = brand;
      _otherBrand = false;
      // A station of another brand no longer fits; pick again.
      final station = _selectedStation;
      if (station != null && _brandOf(station)?.name != brand.name) {
        _selectedStation = null;
      }
      if (_submitted) _validateForm();
    });
  }

  void _selectOtherBrand() {
    setState(() {
      _selectedBrand = null;
      _otherBrand = true;
      if (_submitted) _validateForm();
    });
  }

  void _selectStation(StationModel station) {
    final vm = context.read<ReportViewModel>();
    setState(() {
      _selectedStation = station;
      if (!_otherBrand) _selectedBrand ??= _brandOf(station);
      if (_submitted) _validateForm();
    });
    vm.setStationId(station.id);
    vm.setStationName(station.name);
    vm.setBrand(station.brand);
  }

  static BrandInfo? _brandOf(StationModel s) =>
      BrandRegistry.match(s.brand, stationName: s.name);

  List<StationModel> _stationsForBrand(List<StationModel> stations) {
    final brand = _selectedBrand;
    if (brand == null) return stations;
    return stations.where((s) => _brandOf(s)?.name == brand.name).toList();
  }

  String get _noStationsMessage {
    final brand = _selectedBrand;
    if (brand == null && !_otherBrand) {
      return 'Pick the brand above to see stations near you.';
    }
    if (brand != null) {
      return 'No ${brand.name} stations found near you. Check the brand, '
          'or choose Other.';
    }
    return 'No stations found near you.';
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Check your report',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ReportViewModel>(
                builder: (context, vm, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (vm.imagePath != null) ...[
                      ReportPhotoPreview(
                        imagePath: vm.imagePath!,
                        detectedBrand: vm.detectedBrand?.name,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ReportSection(
                      title: 'Brand',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrandChips(
                            brands: BrandRegistry.brands,
                            selected: _selectedBrand,
                            isOtherSelected: _otherBrand,
                            onSelected: _selectBrand,
                            onOther: _selectOtherBrand,
                          ),
                          FieldError(_brandError),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ReportSection(
                      title: 'Station',
                      hint: vm.latitude != 0 || vm.longitude != 0
                          ? 'Closest to you first, using your location.'
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReportStationPicker(
                            stations: _stationsForBrand(vm.nearbyStations),
                            distances: vm.stationDistances,
                            selected: _selectedStation,
                            emptyMessage: _noStationsMessage,
                            onSelect: _selectStation,
                            onClear: () =>
                                setState(() => _selectedStation = null),
                          ),
                          FieldError(_stationError),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ReportSection(
                      title: 'Prices per liter',
                      hint: "Leave a fuel blank if the board doesn't show it.",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReportPriceRow(
                            grade: 'Regular',
                            product: _productLabel(FuelCategory.regular),
                            color: AppColors.fuelRegular,
                            controller: _regularCtrl,
                            error: _priceErrors.regular,
                            action: TextInputAction.next,
                            onChanged: _revalidate,
                          ),
                          const SizedBox(height: 8),
                          ReportPriceRow(
                            grade: 'Premium',
                            product: _productLabel(FuelCategory.premium),
                            color: AppColors.fuelPremium,
                            controller: _premiumCtrl,
                            error: _priceErrors.premium,
                            action: TextInputAction.next,
                            onChanged: _revalidate,
                          ),
                          const SizedBox(height: 8),
                          ReportPriceRow(
                            grade: 'Diesel',
                            product: _productLabel(FuelCategory.diesel),
                            color: AppColors.fuelDiesel,
                            controller: _dieselCtrl,
                            error: _priceErrors.diesel,
                            action: TextInputAction.done,
                            onChanged: _revalidate,
                          ),
                          FieldError(_priceErrors.general),
                        ],
                      ),
                    ),
                    if (vm.rawOcrText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ReportScanText(text: vm.rawOcrText),
                    ],
                  ],
                ),
              ),
            ),
            Consumer<ReportViewModel>(
              builder: (context, vm, _) {
                final isSubmitting = vm.step == ReportStep.submitting;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppFormError(message: _formError),
                      AppPrimaryButton(
                        label: 'Send report',
                        isLoading: isSubmitting,
                        trailingIcon: Icons.send_rounded,
                        onPressed: isSubmitting ? null : () => _submit(vm),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────

  Future<void> _submit(ReportViewModel vm) async {
    // Update VM with form values
    FocusScope.of(context).unfocus();
    final isValid = _validateForm();
    setState(() {
      _submitted = true;
      _formError = null;
    });
    if (!isValid) return;

    vm.setRegularPrice(parseNumber(_regularCtrl.text) ?? 0.0);
    vm.setPremiumPrice(parseNumber(_premiumCtrl.text) ?? 0.0);
    vm.setDieselPrice(parseNumber(_dieselCtrl.text) ?? 0.0);
    // "Other" keeps whatever brand the station itself has.
    vm.setBrand(_selectedBrand?.name ?? _selectedStation!.brand);
    vm.setStationId(_selectedStation!.id);
    vm.setStationName(_selectedStation!.name);

    // Rules only the view model knows (rate limit, GPS fix).
    final validationError = vm.validateReport();
    if (validationError != null) {
      setState(() => _formError = validationError);
      return;
    }

    final success = await vm.submitReport();
    if (!mounted) return;

    if (success) {
      if (vm.savedOffline) {
        showAppToast(
          context,
          'Saved offline. Will sync when connected.',
          backgroundColor: AppColors.accent,
        );
      }
      Navigator.pushNamedAndRemoveUntil(context, '/success', (route) => false);
    } else {
      setState(
        () => _formError = vm.errorMessage ?? 'Could not submit the report.',
      );
    }
  }
}
