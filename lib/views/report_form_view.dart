import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/report_viewmodel.dart';
import '../models/brand_registry.dart';
import '../models/station_model.dart';
import '../components/app_primary_button.dart';
import '../components/app_circle_button.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/adaptive/app_picker.dart';
import '../ui/adaptive/app_toast.dart';

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
  StationModel? _selectedStation;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back_ios_new,
                    onPressed: () {
                      context.read<ReportViewModel>().reset();
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    'CONFIRM REPORT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer<ReportViewModel>(
                  builder: (context, vm, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview
                        if (vm.imagePath != null) _buildImagePreview(vm),
                        const SizedBox(height: 20),

                        // OCR detected text hint
                        if (vm.rawOcrText.isNotEmpty)
                          _buildOcrHint(vm.rawOcrText),

                        // Brand selector (required)
                        const Text(
                          'SELECT BRAND',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBrandDropdown(),
                        const SizedBox(height: 20),

                        // Station selector (required)
                        const Text(
                          'SELECT STATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStationPicker(context),
                        const SizedBox(height: 20),

                        // Prices section
                        const Text(
                          'FUEL PRICES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPriceField(
                          label: _productLabel(FuelCategory.regular),
                          controller: _regularCtrl,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 10),
                        _buildPriceField(
                          label: _productLabel(FuelCategory.premium),
                          controller: _premiumCtrl,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 10),
                        _buildPriceField(
                          label: _productLabel(FuelCategory.diesel),
                          controller: _dieselCtrl,
                          color: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 20),

                        // Location info
                        if (vm.latitude != 0 || vm.longitude != 0)
                          _buildLocationInfo(vm),

                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Submit button
            Consumer<ReportViewModel>(
              builder: (context, vm, _) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppPrimaryButton(
                    label: 'Submit Report',
                    isLoading: vm.step == ReportStep.submitting,
                    trailingIcon: Icons.send_rounded,
                    onPressed: () => _submit(vm),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Brand Dropdown ──────────────────────────────────────────────

  Widget _buildBrandDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _selectedBrand != null
              ? _selectedBrand!.color.withValues(alpha: 0.30)
              : const Color(0x0A000000),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: isCupertino(context)
          ? _buildBrandPickerRow()
          : DropdownButtonHideUnderline(
              child: DropdownButton<BrandInfo>(
                value: _selectedBrand,
                isExpanded: true,
                hint: const Row(
                  children: [
                    Icon(
                      Icons.local_gas_station,
                      size: 20,
                      color: Color(0xFF71717A),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Choose a brand',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD4D4D8),
                      ),
                    ),
                  ],
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                borderRadius: BorderRadius.circular(18),
                items: BrandRegistry.brands.map((b) {
                  return DropdownMenuItem<BrandInfo>(
                    value: b,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: b.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: b.logo(size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          b.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _selectBrand,
              ),
            ),
    );
  }

  void _selectBrand(BrandInfo? brand) {
    setState(() {
      _selectedBrand = brand;
      // If station was selected from a different brand, clear it
      if (_selectedStation != null &&
          brand != null &&
          _selectedStation!.brand.toLowerCase() != brand.name.toLowerCase()) {
        _selectedStation = null;
      }
    });
  }

  Widget _buildBrandPickerRow() {
    final brand = _selectedBrand;
    return AppTappable(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final picked = await showAppPicker<BrandInfo>(
          context: context,
          items: BrandRegistry.brands,
          labelOf: (b) => b.name,
          selected: brand,
        );
        if (picked != null && mounted) _selectBrand(picked);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: brand == null
                  ? const Row(
                      children: [
                        Icon(
                          Icons.local_gas_station,
                          size: 20,
                          color: Color(0xFF71717A),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Choose a brand',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD4D4D8),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: brand.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: brand.logo(size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          brand.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  // ── Station Picker ──────────────────────────────────────────────

  Widget _buildStationPicker(BuildContext context) {
    final vm = context.read<ReportViewModel>();
    final stations = vm.nearbyStations;
    final distances = vm.stationDistances;

    // Filter stations by selected brand
    final filtered = _selectedBrand != null
        ? stations
              .where(
                (s) =>
                    s.brand.toLowerCase() == _selectedBrand!.name.toLowerCase(),
              )
              .toList()
        : stations;

    if (_selectedStation != null) {
      return _buildSelectedStationCard(distances);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.near_me, size: 18, color: Color(0xFF71717A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    filtered.isNotEmpty
                        ? _selectedBrand != null
                              ? '${_selectedBrand!.name} stations near you'
                              : 'Stations near you'
                        : _selectedBrand != null
                        ? 'No ${_selectedBrand!.name} stations nearby'
                        : 'Select a brand first',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = filtered[i];
                  final accent = brandAccent(s.brand);
                  final dist = distances[s.id];
                  final isNear = dist != null && dist <= 200;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStation = s;
                        _selectedBrand ??= BrandRegistry.findByName(s.brand);
                      });
                      vm.setStationId(s.id);
                      vm.setStationName(s.name);
                      vm.setBrand(s.brand);
                    },
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isNear
                            ? const Color(0xFF16A34A).withValues(alpha: 0.04)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isNear
                              ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                              : const Color(0xFFE5E7EB),
                          width: isNear ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _brandLogo(s.brand, 22),
                              ),
                              const Spacer(),
                              if (dist != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isNear
                                        ? const Color(
                                            0xFF16A34A,
                                          ).withValues(alpha: 0.10)
                                        : const Color(0xFFF4F4F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ReportViewModel.formatDistance(dist),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isNear
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF71717A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            s.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            s.brand,
                            style: TextStyle(
                              fontSize: 10,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (filtered.isEmpty && _selectedBrand != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'No ${_selectedBrand!.name} stations found nearby. Try selecting a different brand.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_selectedBrand == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Please select a brand above to see nearby stations.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedStationCard(Map<String, double> distances) {
    final s = _selectedStation!;
    final accent = brandAccent(s.brand);
    final dist = distances[s.id];
    final isNear = dist != null && dist <= 200;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNear
                  ? const Color(0xFF16A34A).withValues(alpha: 0.30)
                  : accent.withValues(alpha: 0.30),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _brandLogo(s.brand, 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        if (s.brand.isNotEmpty)
                          Text(
                            s.brand,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF71717A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (dist != null) ...[
                          if (s.brand.isNotEmpty)
                            const Text(
                              ' \u2022 ',
                              style: TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 11,
                              ),
                            ),
                          Icon(
                            isNear ? Icons.check_circle : Icons.info_outline,
                            size: 12,
                            color: isNear
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEAB308),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ReportViewModel.formatDistance(dist),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isNear
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFEAB308),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _selectedStation = null);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Warning if not near the station
        if (dist != null && dist > 200)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEAB308).withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You\'re ${ReportViewModel.formatDistance(dist)} away. Make sure you\'re at the station.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _brandLogo(String brandName, double size) {
    final brand = BrandRegistry.findByName(brandName);
    if (brand != null) return brand.logo(size: size);
    return Icon(
      Icons.local_gas_station,
      size: size * 0.7,
      color: brandAccent(brandName),
    );
  }

  // ── Image & OCR ─────────────────────────────────────────────────

  Widget _buildImagePreview(ReportViewModel vm) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(vm.imagePath!), fit: BoxFit.cover),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFBF94FF),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vm.detectedBrand != null
                          ? '${vm.detectedBrand!.name} detected'
                          : 'Image captured',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFBF94FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFBF94FF).withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFBF94FF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OCR detected text',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFBF94FF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.length > 200 ? '${text.substring(0, 200)}...' : text,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF71717A),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Price Field ─────────────────────────────────────────────────

  Widget _buildPriceField({
    required String label,
    required TextEditingController controller,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_gas_station, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3F3F46),
              ),
            ),
          ),
          const Text(
            '\u20B1',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            child: isCupertino(context)
                ? CupertinoTextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                    placeholder: '0.00',
                    placeholderStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Color(0xFFD4D4D8),
                      fontWeight: FontWeight.w700,
                    ),
                    padding: EdgeInsets.zero,
                    decoration: null,
                  )
                : TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: Color(0xFFD4D4D8),
                        fontWeight: FontWeight.w700,
                      ),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Location ────────────────────────────────────────────────────

  Widget _buildLocationInfo(ReportViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Location: ${vm.latitude.toStringAsFixed(4)}, ${vm.longitude.toStringAsFixed(4)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────

  Future<void> _submit(ReportViewModel vm) async {
    // Update VM with form values
    vm.setRegularPrice(double.tryParse(_regularCtrl.text) ?? 0.0);
    vm.setPremiumPrice(double.tryParse(_premiumCtrl.text) ?? 0.0);
    vm.setDieselPrice(double.tryParse(_dieselCtrl.text) ?? 0.0);

    // Require brand
    if (_selectedBrand == null) {
      showAppToast(context, 'Please select a station brand.');
      return;
    }
    vm.setBrand(_selectedBrand!.name);

    // Require station
    if (_selectedStation == null) {
      showAppToast(context, 'Please select a station.');
      return;
    }
    vm.setStationId(_selectedStation!.id);
    vm.setStationName(_selectedStation!.name);

    // Pre-validate before submitting
    final validationError = vm.validateReport();
    if (validationError != null) {
      showAppToast(context, validationError);
      return;
    }

    final success = await vm.submitReport();
    if (!mounted) return;

    if (success) {
      if (vm.savedOffline) {
        showAppToast(
          context,
          'Saved offline. Will sync when connected.',
          backgroundColor: const Color(0xFFBF94FF),
        );
      }
      Navigator.pushNamedAndRemoveUntil(context, '/success', (route) => false);
    } else {
      showAppToast(context, vm.errorMessage ?? 'Could not submit report');
    }
  }
}
