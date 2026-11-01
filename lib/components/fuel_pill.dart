import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

/// Product (or grade) pill in the grade's PH pump colour: "XCS" in Regular
/// blue, "Turbo Diesel" in Diesel green.
class FuelGradePill extends StatelessWidget {
  final String fuelType;
  final String? productName;

  const FuelGradePill({super.key, required this.fuelType, this.productName});

  @override
  Widget build(BuildContext context) {
    final (label, color, tint) = switch (fuelType) {
      'premium' => ('Premium', AppColors.fuelPremium, const Color(0xFFFEE2E2)),
      'diesel' => ('Diesel', AppColors.fuelDiesel, AppColors.goTint),
      _ => ('Regular', AppColors.fuelRegular, const Color(0xFFDBEAFE)),
    };
    final product = productName?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        product.isEmpty ? label : product,
        semanticsLabel: product.isEmpty ? label : '$product, $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
