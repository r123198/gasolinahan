import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';

import '../ui/adaptive/app_platform.dart';
import '../ui/app_theme.dart';
import '../ui/number_input_formatter.dart';
import '../views/fill_up_form_parts.dart' show FieldError;

/// One fuel grade's price input: grade name in its pump colour, product
/// name under it, and a right-aligned ₱ field.
class ReportPriceRow extends StatelessWidget {
  final String grade;
  final String product;
  final Color color;
  final TextEditingController controller;
  final String? error;
  final TextInputAction action;
  final VoidCallback onChanged;

  const ReportPriceRow({
    super.key,
    required this.grade,
    required this.product,
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
          label: '$grade, $product, price in pesos',
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
                        grade,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (product != grade)
                        Text(
                          product,
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
