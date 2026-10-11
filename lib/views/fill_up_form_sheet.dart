import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../components/app_primary_button.dart';
import '../models/brand_registry.dart';
import '../models/fill_up_model.dart';
import '../models/fill_up_validator.dart';
import '../models/station_naming.dart';
import '../models/station_model.dart';
import '../models/station_summary.dart';
import '../services/fill_up_photo_store.dart';
import '../services/odometer_scanner.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_picker.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';
import '../ui/number_input_formatter.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import 'fill_up_form_parts.dart';

const _maxStationChips = 5;
const _photoMaxWidth = 1600.0;
const _fuelLabels = {
  FuelType.regular: 'Regular',
  FuelType.premium: 'Premium',
  FuelType.diesel: 'Diesel',
};

/// Opens the fill-up sheet. Pass [editing] to change a saved fill-up;
/// [station] (one filled at before) or [atStation] (any known station)
/// pre-selects the station for a new one.
Future<void> showFillUpForm(
  BuildContext context, {
  StationSummary? station,
  StationModel? atStation,
  FillUp? editing,
}) {
  final StationChoice? preselected = editing != null
      ? StationChoice(editing.stationId, editing.stationName, editing.brand)
      : station != null
      ? StationChoice(station.stationId, station.stationName, station.brand)
      : atStation != null
      ? StationChoice(atStation.id, atStation.name, atStation.brand)
      : null;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    // Swipe-down would skip the unsaved-changes prompt.
    enableDrag: false,
    builder: (_) => _FillUpForm(preselected: preselected, editing: editing),
  );
}

class _FillUpForm extends StatefulWidget {
  final StationChoice? preselected;
  final FillUp? editing;

  const _FillUpForm({this.preselected, this.editing});

  @override
  State<_FillUpForm> createState() => _FillUpFormState();
}

class _FillUpFormState extends State<_FillUpForm> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scanner = OdometerScanner();
  final _photoStore = FillUpPhotoStore();
  final _picker = ImagePicker();

  late final List<StationChoice> _choices;

  /// The station is set one of three ways: a recent/nearby [_station], a
  /// brand logo ([_brand], with [_nameCtrl] as the branch), or "Other"
  /// ([_typedOther], with [_nameCtrl] as the full name).
  StationChoice? _station;
  BrandInfo? _brand;
  bool _typedOther = false;
  FuelType _fuel = FuelType.regular;
  late DateTime _date;
  List<String> _photos = [];

  /// Photos copied in during this session; deleted again if not saved.
  final Set<String> _addedPhotos = {};
  bool _showNotes = false;
  bool _priceEditedByUser = false;
  bool _isDirty = false;
  bool _isSaving = false;
  bool _isScanning = false;
  bool _submitted = false;
  FillUpErrors _errors = const FillUpErrors();

  bool get _isEditing => widget.editing != null;
  bool get _isOther => _typedOther;

  /// Brand logo to highlight: the picked brand, or the picked station's.
  BrandInfo? get _highlightedBrand {
    final station = _station;
    if (station != null) {
      return BrandRegistry.match(station.brand, stationName: station.name);
    }
    return _brand;
  }

  @override
  void initState() {
    super.initState();
    final fillUps = context.read<FillUpViewModel>();
    _choices = _buildChoices();
    final editing = widget.editing;
    if (editing != null) {
      _station = _choices
          .where(
            (c) => c.id == editing.stationId && c.name == editing.stationName,
          )
          .firstOrNull;
      if (_station == null) {
        _brand = BrandRegistry.match(
          editing.brand,
          stationName: editing.stationName,
        );
        _typedOther = _brand == null;
        _nameCtrl.text = _brand == null
            ? editing.stationName
            : branchOf(editing.stationName, _brand!);
      }
      _fuel = FuelType.values.asNameMap()[editing.fuelType] ?? FuelType.regular;
      _date = editing.timestamp;
      _amountCtrl.text = editing.amountSpent.toStringAsFixed(2);
      _priceCtrl.text =
          editing.effectivePricePerLiter?.toStringAsFixed(2) ?? '';
      _priceEditedByUser = true;
      _odometerCtrl.text = editing.odometerKm.round().toString();
      _notesCtrl.text = editing.notes;
      _showNotes = editing.notes.isNotEmpty;
      _photos = [...editing.photoPaths];
    } else {
      _station = widget.preselected == null
          ? null
          : _choices.firstWhere(
              (c) => c == widget.preselected,
              orElse: () => widget.preselected!,
            );
      // Most people buy the same fuel every time.
      final lastFuel = fillUps.latest?.fuelType;
      _fuel =
          FuelType.values.asNameMap()[lastFuel] ??
          context.read<DashboardViewModel>().fuelType;
      _date = DateTime.now();
      _prefillPrice();
    }
    for (final c in [
      _nameCtrl,
      _amountCtrl,
      _priceCtrl,
      _odometerCtrl,
      _notesCtrl,
    ]) {
      c.addListener(_onEdited);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _amountCtrl,
      _priceCtrl,
      _odometerCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

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

  void _onEdited() {
    _isDirty = true;
    // Once the user has tried to save, keep errors in step with typing.
    if (_submitted) {
      setState(() => _errors = _validate());
    } else {
      setState(() {});
    }
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
            (s) => switch (_fuel) {
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

  void _changeStation(VoidCallback change) {
    setState(() {
      change();
      _isDirty = true;
      _prefillPrice();
      if (_submitted) _errors = _validate();
    });
  }

  void _selectStation(StationChoice choice) => _changeStation(() {
    _station = choice;
    _brand = null;
    _typedOther = false;
  });

  void _selectBrand(BrandInfo brand) => _changeStation(() {
    _station = null;
    _brand = brand;
    _typedOther = false;
  });

  void _selectOther() => _changeStation(() {
    _station = null;
    _brand = null;
    _typedOther = true;
  });

  Future<void> _pickFromAllStations() async {
    final picked = await showAppPicker<StationChoice>(
      context: context,
      items: _choices,
      labelOf: (c) => c.brand.isEmpty ? c.name : '${c.name} · ${c.brand}',
      selected: _station,
    );
    if (picked != null && mounted) _selectStation(picked);
  }

  void _selectFuel(FuelType fuel) {
    setState(() {
      _fuel = fuel;
      _isDirty = true;
      _prefillPrice();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Fill-up date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      // Keep the time of day; only the day changes.
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
      _isDirty = true;
      if (_submitted) _errors = _validate();
    });
  }

  Future<void> _scanOdometer() async {
    setState(() => _isScanning = true);
    final result = await _scanner.scan();
    if (!mounted) return;
    setState(() => _isScanning = false);
    switch (result.status) {
      case OdometerScanStatus.read:
        _odometerCtrl.text = result.km!.round().toString();
        showAppToast(
          context,
          'Read ${result.km!.round()} km. Check it looks right.',
        );
      case OdometerScanStatus.unreadable:
        showAppToast(
          context,
          "Couldn't read the odometer. Try again or type it.",
        );
      case OdometerScanStatus.failed:
        showAppToast(context, 'Camera unavailable. Type the odometer instead.');
      case OdometerScanStatus.cancelled:
        break;
    }
  }

  Future<void> _addPhotos() async {
    final source = await showAppActionSheet<ImageSource>(
      context: context,
      actions: const [
        AppSheetAction(
          label: 'Take a photo',
          value: ImageSource.camera,
          icon: Icons.photo_camera_outlined,
        ),
        AppSheetAction(
          label: 'Choose from gallery',
          value: ImageSource.gallery,
          icon: Icons.photo_library_outlined,
        ),
      ],
    );
    if (source == null) return;
    final room = maxPhotosPerFill - _photos.length;
    // pickMultiImage rejects a limit below 2.
    final picked = source == ImageSource.camera || room < 2
        ? [
            ?await _picker.pickImage(
              source: source,
              imageQuality: 70,
              maxWidth: _photoMaxWidth,
            ),
          ]
        : await _picker.pickMultiImage(
            imageQuality: 70,
            maxWidth: _photoMaxWidth,
            limit: room,
          );
    if (picked.isEmpty || !mounted) return;
    final kept = <String>[];
    for (final file in picked.take(room)) {
      kept.add(await _photoStore.keep(file.path));
    }
    if (!mounted) return;
    setState(() {
      _addedPhotos.addAll(kept);
      _photos = [..._photos, ...kept];
      _isDirty = true;
    });
  }

  void _removePhoto(String path) {
    setState(() {
      _photos = _photos.where((p) => p != path).toList();
      _isDirty = true;
    });
    if (_addedPhotos.remove(path)) _photoStore.discard([path]);
  }

  FillUpDraft get _draft => FillUpDraft(
    stationName: switch ((_station, _brand)) {
      (final StationChoice s, _) => s.name,
      (_, final BrandInfo b) => composeStationName(b, _nameCtrl.text),
      _ => _typedOther ? _nameCtrl.text : null,
    },
    amountText: _amountCtrl.text,
    pricePerLiterText: _priceCtrl.text,
    odometerText: _odometerCtrl.text,
    date: _date,
    notes: _notesCtrl.text.trim(),
  );

  FillUpErrors _validate() {
    final editingId = widget.editing?.id;
    final others = context
        .read<FillUpViewModel>()
        .fillUps
        .where((f) => editingId == null || f.id != editingId)
        .toList();
    return validateFillUp(_draft, others: others, now: DateTime.now());
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final errors = _validate();
    setState(() {
      _submitted = true;
      _errors = errors;
    });
    if (!errors.isEmpty) return;

    final draft = _draft;
    final station = _station;
    final vm = context.read<FillUpViewModel>();
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    final fillUp = FillUp(
      id: widget.editing?.id,
      stationId: station?.id ?? '',
      stationName: draft.stationName!.trim(),
      // A typed "Petron Mayapa" still gets Petron's logo and colours.
      brand: switch (station?.brand) {
        final String b when b.isNotEmpty => b,
        _ =>
          _brand?.name ??
              BrandRegistry.inferFromName(draft.stationName!)?.name ??
              '',
      },
      fuelType: _fuel.name,
      amountSpent: draft.amount!,
      liters: draft.liters,
      pricePerLiter: draft.pricePerLiter,
      odometerKm: draft.odometer!,
      timestamp: _date,
      notes: draft.notes,
      photoPaths: List.unmodifiable(_photos),
    );
    final editing = widget.editing;
    final saved = editing == null
        ? await vm.add(fillUp)
        : await vm.update(
            fillUp,
            removedPhotos: editing.photoPaths.where(
              (p) => !_photos.contains(p),
            ),
          );
    if (!mounted) return;
    if (!saved) {
      setState(() => _isSaving = false);
      showAppToast(context, vm.errorMessage ?? 'Could not save.');
      return;
    }
    _addedPhotos.clear(); // now owned by the saved fill-up
    showAppToast(context, _isEditing ? 'Changes saved' : 'Fill-up saved');
    navigator.pop();
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) {
      _photoStore.discard(_addedPhotos);
      return;
    }
    final discard = await showAppConfirmDialog(
      context: context,
      title: _isEditing ? 'Discard changes?' : 'Discard this fill-up?',
      message: "What you've entered won't be saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      isDestructive: true,
    );
    if (!discard || !mounted) return;
    setState(() => _isDirty = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // The iOS sheet already lifts itself above the keyboard.
    final keyboard = isCupertino(context)
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;
    final liters = _draft.liters;
    final lastOdometer = context.read<FillUpViewModel>().lastOdometer;
    final chips = _choices.take(_maxStationChips).toList();
    final selected = _station;
    if (selected != null && !chips.contains(selected)) {
      chips.insert(0, selected);
    }
    final brand = _brand;

    return PopScope(
      canPop: _isSaving || !_isDirty,
      onPopInvokedWithResult: _onPopInvoked,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _isEditing ? 'Edit fill-up' : 'Log a fill-up',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event_outlined, size: 18),
                  label: Text(formatDayLabel(_date)),
                  tooltip: 'Change date',
                  onPressed: _pickDate,
                ),
              ],
            ),
            FieldError(_errors.date),
            const SizedBox(height: 16),
            if (chips.isNotEmpty) ...[
              const FormLabel('Recent & nearby'),
              StationChips(
                choices: chips,
                selected: _station,
                isOther: false,
                onSelected: _selectStation,
                onMore: _choices.length > chips.length
                    ? _pickFromAllStations
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            FormLabel(chips.isEmpty ? 'Station brand' : 'Or pick a brand'),
            BrandChips(
              brands: BrandRegistry.brands,
              selected: _highlightedBrand,
              isOtherSelected: _typedOther,
              onSelected: _selectBrand,
              onOther: _selectOther,
            ),
            if (brand != null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Branch or area (optional)',
                  hintText: 'e.g. Mayapa',
                  helperText:
                      'Saved as "${composeStationName(brand, _nameCtrl.text)}"',
                ),
              ),
            ] else if (_typedOther) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Station name',
                  hintText: 'e.g. Kuya Ben Gasoline',
                  errorText: _errors.station,
                ),
              ),
            ] else
              FieldError(_errors.station),
            const SizedBox(height: 20),
            const FormLabel('Fuel'),
            SegmentedButton<FuelType>(
              segments: [
                for (final f in FuelType.values)
                  ButtonSegment(value: f, label: Text(_fuelLabels[f]!)),
              ],
              selected: {_fuel},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _selectFuel(s.first),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    controller: _amountCtrl,
                    label: 'Amount paid',
                    prefix: '₱ ',
                    error: _errors.amount,
                    autofocus: !_isEditing && _station != null && !_isOther,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    controller: _priceCtrl,
                    label: 'Price per liter',
                    prefix: '₱ ',
                    error: _errors.pricePerLiter,
                    onChanged: (_) => _priceEditedByUser = true,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                liters == null
                    ? 'Liters are worked out from these two.'
                    : '= ${formatLiters(liters)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: liters == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                  color: liters == null ? AppColors.textMuted : AppColors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _numberField(
              controller: _odometerCtrl,
              label: 'Odometer',
              suffixText: 'km',
              decimal: false,
              error: _errors.odometer,
              helper: lastOdometer == null || _isEditing
                  ? null
                  : 'Last fill-up: ${formatKm(lastOdometer)}',
              action: TextInputAction.done,
              suffixIcon: _isScanning
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: AppSpinner(size: 20, strokeWidth: 2),
                    )
                  : AppIconButton(
                      tooltip: 'Scan odometer',
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: _scanOdometer,
                    ),
            ),
            const SizedBox(height: 16),
            if (_showNotes)
              TextField(
                controller: _notesCtrl,
                autofocus: !_isEditing,
                maxLines: 3,
                minLines: 1,
                maxLength: maxNotesLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. Pricelocq discount, full tank',
                  errorText: _errors.notes,
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showNotes = true),
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                  label: const Text('Add a note'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                ),
              ),
            const SizedBox(height: 12),
            const FormLabel('Photos (optional)'),
            PhotoStrip(
              paths: _photos,
              max: maxPhotosPerFill,
              onAdd: _addPhotos,
              onRemove: _removePhoto,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: _isEditing ? 'Save changes' : 'Save fill-up',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
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
