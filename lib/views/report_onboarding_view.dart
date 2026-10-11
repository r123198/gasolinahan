import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/app_theme.dart';
import '../components/app_primary_button.dart';

class ReportOnboardingView extends StatefulWidget {
  const ReportOnboardingView({super.key});

  @override
  State<ReportOnboardingView> createState() => _ReportOnboardingViewState();
}

class _ReportOnboardingViewState extends State<ReportOnboardingView> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      image: null,
      icon: Icons.camera_alt_rounded,
      title: 'Report fuel prices',
      subtitle:
          'Help fellow drivers by reporting the latest fuel prices at stations near you. '
          'It only takes a few seconds.',
      tips: [
        _Tip(Icons.location_on_rounded, 'Go to a gas station'),
        _Tip(Icons.camera_alt_rounded, 'Take a photo of the price board'),
        _Tip(Icons.check_circle_rounded, 'Confirm and submit'),
      ],
    ),
    _OnboardingPage(
      image: 'assets/images/samples/priceboard_shell.jpg',
      icon: null,
      title: 'Capture the price board',
      subtitle:
          'Point your camera at the station\'s price board like this. '
          'Make sure the prices and brand name are clearly visible.',
      tips: [
        _Tip(Icons.wb_sunny_rounded, 'Make sure there\'s good lighting'),
        _Tip(Icons.crop_free_rounded, 'Fill the frame with the board'),
        _Tip(Icons.straighten_rounded, 'Keep your phone steady'),
        _Tip(Icons.block_rounded, 'Avoid glare and obstructions'),
        _Tip(Icons.photo_camera_rounded, 'Only real photos — no screenshots'),
      ],
    ),
    _OnboardingPage(
      image: null,
      icon: Icons.rate_review_rounded,
      title: 'Review and submit',
      subtitle:
          'After scanning, you can review the detected prices and station before '
          'submitting. You can also correct any values if needed.',
      tips: [
        _Tip(Icons.edit_rounded, 'Edit prices if the scan missed something'),
        _Tip(Icons.store_rounded, 'Select the correct station'),
        _Tip(Icons.verified_rounded, 'Your report helps thousands of drivers'),
      ],
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _next() {
    if (_isLastPage) {
      Navigator.pop(context, true);
    } else {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.jumpToPage(_currentPage + 1);
        return;
      }
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppIconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                  AppTextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _buildPage(_pages[i]),
              ),
            ),

            // Bottom section: indicator + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: WormEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      spacing: 10,
                      dotColor: AppColors.divider,
                      activeDotColor: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppPrimaryButton(
                    label: _isLastPage ? 'Start scanning' : 'Next',
                    trailingIcon: _isLastPage
                        ? Icons.photo_camera_outlined
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Image or icon
          if (page.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(
                  page.image!,
                  fit: BoxFit.cover,
                  semanticLabel: 'Example of a clear price board photo',
                ),
              ),
            )
          else
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: Icon(
                page.icon ?? Icons.local_gas_station_rounded,
                size: 52,
                color: AppColors.distance,
              ),
            ),

          const SizedBox(height: 28),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Tips
          ...page.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tip.icon, size: 18, color: AppColors.ink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tip.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String? image;
  final IconData? icon;
  final String title;
  final String subtitle;
  final List<_Tip> tips;

  const _OnboardingPage({
    required this.image,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tips,
  });
}

class _Tip {
  final IconData icon;
  final String text;

  const _Tip(this.icon, this.text);
}
