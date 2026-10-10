import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/report_viewmodel.dart';
import '../components/app_primary_button.dart';
import '../components/app_list_tile.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';

class SuccessView extends StatelessWidget {
  const SuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReportViewModel>();
    final price = vm.regularPrice > 0
        ? vm.regularPrice
        : (vm.premiumPrice > 0 ? vm.premiumPrice : vm.dieselPrice);
    final fuelType = vm.regularPrice > 0
        ? 'Regular'
        : (vm.premiumPrice > 0 ? 'Premium' : 'Diesel');
    final stationLabel = vm.stationName.isNotEmpty
        ? vm.stationName
        : 'Unknown Station';
    final brandLabel = vm.brand.isNotEmpty ? vm.brand : '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 120,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      vm.savedOffline ? 'Saved Offline' : 'Report Received',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vm.savedOffline
                          ? 'Will sync when you\'re back online.'
                          : 'Thanks for helping update prices.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 40,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SCANNED PRICE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        formatPhp(price),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -2,
                                        ),
                                      ),
                                      Text(
                                        '/L',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.local_gas_station,
                                  size: 24,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          AppDetailRow(
                            icon: Icons.storefront,
                            text: brandLabel.isNotEmpty
                                ? '$stationLabel ($brandLabel)'
                                : stationLabel,
                          ),
                          AppDetailRow(icon: Icons.category, text: fuelType),
                          const AppDetailRow(
                            icon: Icons.schedule,
                            text: 'Just now',
                          ),
                          if (vm.savedOffline)
                            const AppDetailRow(
                              icon: Icons.cloud_off,
                              text: 'Pending sync',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppPrimaryButton(
                label: 'Return to Map',
                borderRadius: 32,
                elevation: 8,
                onPressed: () {
                  // Reset the report viewmodel
                  context.read<ReportViewModel>().reset();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
