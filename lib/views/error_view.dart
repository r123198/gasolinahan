import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/report_viewmodel.dart';
import '../components/app_primary_button.dart';
import '../components/app_circle_button.dart';
import '../ui/app_theme.dart';

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
      title = 'Not a price board';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('Could not find any fuel prices')) {
      icon = Icons.search_off_rounded;
      title = 'No prices found';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('doesn\'t appear to be taken with a camera')) {
      icon = Icons.no_photography_outlined;
      title = 'Photo not from a camera';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('image appears to be old')) {
      icon = Icons.history_rounded;
      title = 'Photo is too old';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('resolution is too low')) {
      icon = Icons.broken_image_outlined;
      title = 'Photo is too blurry';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('No gas stations found nearby')) {
      icon = Icons.location_off_rounded;
      title = 'No stations nearby';
      subtitle = error;
      showRetry = false;
    } else if (error.contains('Could not open camera')) {
      icon = Icons.camera_alt_outlined;
      title = 'Camera problem';
      subtitle = error;
      showRetry = true;
    } else if (error.contains('Image file not found')) {
      icon = Icons.broken_image_outlined;
      title = 'Photo not found';
      subtitle = error;
      showRetry = true;
    } else {
      icon = Icons.error_outline_rounded;
      title = 'Something went wrong';
      subtitle = error;
      showRetry = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 52, color: AppColors.bad),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  if (showRetry) ...[
                    AppPrimaryButton(
                      label: 'Try again',
                      trailingIcon: Icons.photo_camera_outlined,
                      onPressed: () {
                        vm.reset();
                        Navigator.pushReplacementNamed(context, '/report');
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppSecondaryButton(
                    label: 'Back to home',
                    onPressed: () {
                      vm.reset();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/dashboard',
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
