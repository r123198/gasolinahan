import 'package:flutter/services.dart';

final _decimalPattern = RegExp(r'^[0-9,]*(\.[0-9]{0,2})?$');
final _wholePattern = RegExp(r'^[0-9,]*$');

/// Keeps numeric fields to digits, thousands commas and (when [decimal])
/// at most one point with two decimals, so "62,50" or "62.5.0" can't be
/// typed in the first place.
TextInputFormatter numberInputFormatter({bool decimal = true}) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final pattern = decimal ? _decimalPattern : _wholePattern;
      return pattern.hasMatch(newValue.text) ? newValue : oldValue;
    });
