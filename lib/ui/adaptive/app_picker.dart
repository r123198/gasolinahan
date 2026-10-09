import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_platform.dart';

const _pickerHeight = 216.0;
const _pickerItemExtent = 40.0;

/// Single-choice picker. iOS shows a wheel ([CupertinoPicker]) with a Done
/// button; Android shows a list in a bottom sheet. Returns the chosen item,
/// or null if dismissed.
Future<T?> showAppPicker<T>({
  required BuildContext context,
  required List<T> items,
  required String Function(T item) labelOf,
  T? selected,
  String doneLabel = 'Done',
}) {
  if (items.isEmpty) return Future.value(null);
  if (!isCupertino(context)) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in items)
              ListTile(
                title: Text(labelOf(item)),
                selected: item == selected,
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    );
  }

  var index = selected == null
      ? 0
      : items.indexOf(selected).clamp(0, items.length - 1);
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (popupContext) => Container(
      height: _pickerHeight + 52,
      padding: const EdgeInsets.only(top: 6),
      color: CupertinoColors.systemBackground.resolveFrom(popupContext),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.pop(popupContext, items[index]),
                child: Text(doneLabel),
              ),
            ),
            Expanded(
              child: _PickerWheel(
                initialIndex: index,
                labels: [for (final item in items) labelOf(item)],
                onChanged: (value) => index = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickerWheel extends StatefulWidget {
  final int initialIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _PickerWheel({
    required this.initialIndex,
    required this.labels,
    required this.onChanged,
  });

  @override
  State<_PickerWheel> createState() => _PickerWheelState();
}

class _PickerWheelState extends State<_PickerWheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: _controller,
      itemExtent: _pickerItemExtent,
      onSelectedItemChanged: widget.onChanged,
      children: [for (final label in widget.labels) Center(child: Text(label))],
    );
  }
}
