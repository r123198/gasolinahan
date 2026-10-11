import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/app_theme.dart';
import '../ui/number_input_formatter.dart';
import '../views/fill_up_form_parts.dart' show FieldError;

/// Pump colour for a fuel grade (Regular blue, Premium red, Diesel green).
Color gradeColor(FuelCategory grade) => switch (grade) {
  FuelCategory.regular => AppColors.fuelRegular,
  FuelCategory.premium => AppColors.fuelPremium,
  FuelCategory.diesel => AppColors.fuelDiesel,
};

String gradeLabel(FuelCategory grade) => switch (grade) {
  FuelCategory.regular => 'Regular',
  FuelCategory.premium => 'Premium',
  FuelCategory.diesel => 'Diesel',
};

/// One price input: [title] (a product like "Turbo Diesel", or a grade) in
/// its grade's pump colour, [subtitle] under it (the grade, or the brand's
/// product for a grade row), and a right-aligned ₱ field.
class ReportPriceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final TextEditingController controller;
  final String? error;
  final TextInputAction action;
  final VoidCallback onChanged;

  const ReportPriceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.controller,
    required this.action,
    required this.onChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const hintStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 18,
      color: AppColors.textMuted,
    );
    final field = isCupertino(context)
        ? CupertinoTextField(
            controller: controller,
            textInputAction: action,
            inputFormatters: [numberInputFormatter()],
            onChanged: (_) => onChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: valueStyle,
            placeholder: '0.00',
            placeholderStyle: hintStyle,
            padding: EdgeInsets.zero,
            decoration: null,
          )
        : TextField(
            controller: controller,
            textInputAction: action,
            inputFormatters: [numberInputFormatter()],
            onChanged: (_) => onChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: valueStyle,
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: hintStyle,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: title == subtitle
              ? '$title, price in pesos'
              : '$title, $subtitle, price in pesos',
          textField: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: error != null ? AppColors.error : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_gas_station, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (subtitle != title)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 80,
                    maxWidth: 120,
                  ),
                  child: IntrinsicWidth(child: field),
                ),
              ],
            ),
          ),
        ),
        FieldError(error),
      ],
    );
  }
}
