import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_logo.dart';
import '../components/app_primary_button.dart';
import '../components/brand_logo.dart';
import '../components/report_points_card.dart';
import '../components/report_price_row.dart' show gradeColor;
import '../models/brand_registry.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';

class SuccessView extends StatelessWidget {
  const SuccessView({super.key});

  void _backToMap(BuildContext context) {
    context.read<ReportViewModel>().reset();
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReportViewModel>();
    final station = vm.stationName.isNotEmpty ? vm.stationName : 'Station';
    final brand = BrandRegistry.findByName(vm.brand);
    // Each product reported (e.g. XCS, Turbo Diesel), in the brand's order;
    // the three grades when the brand's products aren't known.
    final prices = brand != null && vm.productPrices.isNotEmpty
        ? [
            for (final p in brand.products)
              if (vm.productPrices[p.name] case final price?)
                (p.name, price, gradeColor(p.category)),
          ]
        : [
            ('Regular', vm.regularPrice, AppColors.fuelRegular),
            ('Premium', vm.premiumPrice, AppColors.fuelPremium),
            ('Diesel', vm.dieselPrice, AppColors.fuelDiesel),
          ].where((p) => p.$2 > 0).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  const Center(child: AppLogo(size: 72)),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      vm.savedOffline ? 'Saved offline' : 'Report sent',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vm.savedOffline
                        ? "We'll send it as soon as you're back online."
                        : 'Thanks! Drivers nearby can see these prices now.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (vm.lastAward case final award?) ...[
                    const SizedBox(height: 24),
                    ReportPointsCard(
                      award: award,
                      savedOffline: vm.savedOffline,
                      lifetimeBefore: context
                          .read<AuthViewModel>()
                          .currentUser
                          ?.lifetimePoints,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: ExcludeSemantics(
                                child: brandLogoWidget(
                                  vm.brand,
                                  30,
                                  stationName: station,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    station,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    vm.savedOffline
                                        ? 'Waiting to sync'
                                        : 'Reported just now',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            for (final (i, (label, price, color))
                                in prices.indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _PriceTile(
                                  label: label,
                                  price: price,
                                  color: color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: AppPrimaryButton(
                label: 'Back to map',
                onPressed: () => _backToMap(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  final String label;
  final double price;
  final Color color;

  const _PriceTile({
    required this.label,
    required this.price,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatPhp(price)}/L',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
