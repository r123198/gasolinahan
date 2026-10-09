import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/report_viewmodel.dart';
import '../components/app_primary_button.dart';
import '../ui/adaptive/app_icon_button.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReportViewModel>();
    final error = vm.errorMessage ?? 'Something went wrong';

    // Determine icon/title/subtitle based on the error
    final IconData icon;
    final String title;
    final String subtitle;
    final bool showRetry;

    if (error.contains('doesn\'t look like a fuel price board')) {
      icon = Icons.image_not_supported_outlined;
      title = 'Not a Price Board';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('Could not find any fuel prices')) {
      icon = Icons.search_off_rounded;
      title = 'No Prices Found';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('doesn\'t appear to be taken with a camera')) {
      icon = Icons.no_photography_outlined;
      title = 'Invalid Image';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('image appears to be old')) {
      icon = Icons.history_rounded;
      title = 'Stale Image';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('resolution is too low')) {
      icon = Icons.broken_image_outlined;
      title = 'Low Quality Image';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('No gas stations found nearby')) {
      icon = Icons.location_off_rounded;
      title = 'No Stations Nearby';
      subtitle = error;
      showRetry = false;
    } else if (error.contains('Could not open camera')) {
      icon = Icons.camera_alt_outlined;
      title = 'Camera Error';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('Image file not found')) {
      icon = Icons.broken_image_outlined;
      title = 'Image Not Found';
      subtitle = error;
      showRetry = true;
    } else {
      icon = Icons.error_outline_rounded;
      title = 'Something Went Wrong';
      subtitle = error;
      showRetry = true;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 48),
                      child: Text(
                        'Report Issue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 56,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (showRetry)
                      AppPrimaryButton(
                        label: 'Try Again',
                        borderRadius: 32,
                        onPressed: () {
                          vm.reset();
                          Navigator.pushReplacementNamed(context, '/report');
                        },
                      ),
                    if (showRetry) const SizedBox(height: 16),
                    AppSecondaryButton(
                      label: 'Back to Home',
                      onPressed: () {
                        vm.reset();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/dashboard',
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
