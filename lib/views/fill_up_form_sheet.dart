import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_primary_button.dart';
import '../models/fill_up_model.dart';
import '../models/station_model.dart';
import '../models/station_summary.dart';
import '../services/odometer_scanner.dart';
import '../ui/adaptive/app_picker.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_toast.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/fill_up_viewmodel.dart';

/// A station choice in the fill-up form. An empty [id] means "typed by hand".
class _StationChoice {
  final String id;
  final String name;
  final String brand;
  const _StationChoice(this.id, this.name, this.brand);
}

const _otherChoice = _StationChoice('', 'Other station…', '');
const _fuelLabels = {
  FuelType.regular: 'Regular',
  FuelType.premium: 'Premium',
  FuelType.diesel: 'Diesel',
};

/// Opens the "Log a fill-up" sheet. [station] pre-selects a station.
Future<void> showFillUpForm(BuildContext context, {StationSummary? station}) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FillUpForm(preselected: station),
  );
}

class _FillUpForm extends StatefulWidget {
  final StationSummary? preselected;
  const _FillUpForm({this.preselected});

  @override
  State<_FillUpForm> createState() => _FillUpFormState();
}

class _FillUpFormState extends State<_FillUpForm> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();
  late List<_StationChoice> _choices;
  _StationChoice? _station;
  FuelType _fuel = FuelType.regular;
  bool _isSaving = false;
  bool _isScanning = false;
  final _scanner = OdometerScanner();

  @override
  void initState() {
    super.initState();
    _fuel = context.read<DashboardViewModel>().fuelType;
    _choices = _buildChoices();
    final pre = widget.preselected;
    if (pre != null) {
      _station = _choices.firstWhere(
        (c) => c.id == pre.stationId && c.name == pre.stationName,
        orElse: () => _StationChoice(pre.stationId, pre.stationName, pre.brand),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _litersCtrl.dispose();
    _odometerCtrl.dispose();
    super.dispose();
  }

  List<_StationChoice> _buildChoices() {
    final seen = <String>{};
    final choices = <_StationChoice>[];
    void add(_StationChoice c) {
      if (seen.add('${c.id}|${c.name}')) choices.add(c);
    }

    for (final s in context.read<FillUpViewModel>().summaries) {
      add(_StationChoice(s.stationId, s.stationName, s.brand));
    }
    for (final StationModel s in context.read<DashboardViewModel>().nearbyStations) {
      add(_StationChoice(s.id, s.name, s.brand));
    }
    return [...choices, _otherChoice];
  }

  bool get _isOther => _station == _otherChoice;

  Future<void> _pickStation() async {
    final picked = await showAppPicker<_StationChoice>(
      context: context,
      items: _choices,
      labelOf: (c) => c.brand.isEmpty ? c.name : '${c.name} · ${c.brand}',
      selected: _station,
    );
    if (picked != null && mounted) setState(() => _station = picked);
  }

  Future<void> _pickFuel() async {
    final picked = await showAppPicker<FuelType>(
      context: context,
      items: FuelType.values,
      labelOf: (f) => _fuelLabels[f]!,
      selected: _fuel,
    );
    if (picked != null && mounted) setState(() => _fuel = picked);
  }

  Future<void> _scanOdometer() async {
    setState(() => _isScanning = true);
    final result = await _scanner.scan();
    if (!mounted) return;
    setState(() => _isScanning = false);
    switch (result.status) {
      case OdometerScanStatus.read:
        _odometerCtrl.text = result.km!.round().toString();
        showAppToast(context, 'Read ${result.km!.round()} km — check it looks right.');
      case OdometerScanStatus.unreadable:
        showAppToast(context, "Couldn't read the odometer. Try again or type it.");
      case OdometerScanStatus.failed:
        showAppToast(context, 'Camera unavailable. Type the odometer instead.');
      case OdometerScanStatus.cancelled:
        break;
    }
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  String? _validate() {
    final station = _station;
    if (station == null) return 'Choose a station.';
    if (_isOther && _nameCtrl.text.trim().isEmpty) {
      return 'Enter the station name.';
    }
    final amount = _parse(_amountCtrl);
    if (amount == null || amount <= 0) return 'Enter how much you spent.';
    final odometer = _parse(_odometerCtrl);
    if (odometer == null || odometer <= 0) return 'Enter your odometer reading.';
    final last = context.read<FillUpViewModel>().lastOdometer;
    if (last != null && odometer < last) {
      return 'Odometer is lower than your last entry (${last.round()} km).';
    }
    if (_litersCtrl.text.trim().isNotEmpty) {
      final liters = _parse(_litersCtrl);
      if (liters == null || liters <= 0) return 'Liters must be a positive number.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      showAppToast(context, error);
      return;
    }
    final station = _station!;
    final vm = context.read<FillUpViewModel>();
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    final fillUp = FillUp(
      stationId: station.id,
      stationName: _isOther ? _nameCtrl.text.trim() : station.name,
      brand: station.brand,
      fuelType: _fuel.name,
      amountSpent: _parse(_amountCtrl)!,
      liters: _litersCtrl.text.trim().isEmpty ? null : _parse(_litersCtrl),
      odometerKm: _parse(_odometerCtrl)!,
      timestamp: DateTime.now(),
    );
    final saved = await vm.add(fillUp);
    if (!mounted) return;
    if (saved) {
      navigator.pop();
    } else {
      setState(() => _isSaving = false);
      showAppToast(context, vm.errorMessage ?? 'Could not save.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log a fill-up',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),
          _SelectRow(
            label: 'Station',
            value: _station?.name ?? 'Choose a station',
            isPlaceholder: _station == null,
            onTap: _pickStation,
          ),
          if (_isOther) ...[
            const SizedBox(height: 12),
            _field(_nameCtrl, 'Station name', keyboard: TextInputType.text),
          ],
          const SizedBox(height: 12),
          _SelectRow(
            label: 'Fuel',
            value: _fuelLabels[_fuel]!,
            onTap: _pickFuel,
          ),
          const SizedBox(height: 12),
          _field(_amountCtrl, 'Amount spent (₱)'),
          const SizedBox(height: 12),
          _field(
            _odometerCtrl,
            'Odometer (km)',
            suffix: _isScanning
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Scan odometer',
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: _scanOdometer,
                  ),
          ),
          const SizedBox(height: 12),
          _field(_litersCtrl, 'Liters (optional)'),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'Save fill-up',
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = const TextInputType.numberWithOptions(decimal: true),
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F6F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _SelectRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isPlaceholder
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more_rounded,
                size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
