import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/app_theme.dart';
import '../ui/adaptive/app_platform.dart';

class ReportOnboardingView extends StatefulWidget {
  const ReportOnboardingView({super.key});

  @override
  State<ReportOnboardingView> createState() => _ReportOnboardingViewState();
}

class _ReportOnboardingViewState extends State<ReportOnboardingView> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _green = Color(0xFF22C55E);
  static const _charcoal = Color(0xFF111827);
  static const _grey = Color(0xFF64748B);

  static const _pages = [
    _OnboardingPage(
      image: null,
      icon: Icons.camera_alt_rounded,
      title: 'Report Fuel Prices',
      subtitle:
          'Help fellow drivers by reporting the latest fuel prices at stations near you. '
          'It only takes a few seconds!',
      tips: [
        _Tip(Icons.location_on_rounded, 'Go to a gas station'),
        _Tip(Icons.camera_alt_rounded, 'Take a photo of the price board'),
        _Tip(Icons.check_circle_rounded, 'Confirm and submit'),
      ],
    ),
    _OnboardingPage(
      image: 'assets/images/samples/priceboard_shell.jpg',
      icon: null,
      title: 'Capture the Price Board',
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
      title: 'Review & Submit',
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
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
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
      backgroundColor: const Color(0xFFF4F6F9),
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
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _grey,
                      size: 24,
                    ),
                  ),
                  AppTextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: _grey,
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
                      dotColor: _charcoal.withValues(alpha: 0.12),
                      activeDotColor: _charcoal,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: isCupertino(context)
                        ? CupertinoButton(
                            onPressed: _next,
                            padding: EdgeInsets.zero,
                            color: _isLastPage ? _green : _charcoal,
                            borderRadius: BorderRadius.circular(16),
                            child: _buildNextButtonContent(),
                          )
                        : ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLastPage ? _green : _charcoal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _buildNextButtonContent(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButtonContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLastPage ? 'Start Scanning' : 'Next',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          _isLastPage ? Icons.camera_alt_rounded : Icons.arrow_forward_rounded,
          size: 20,
          color: Colors.white,
        ),
      ],
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
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(page.image!, fit: BoxFit.cover),
              ),
            )
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.local_gas_station_rounded,
                size: 52,
                color: _green,
              ),
            ),

          const SizedBox(height: 28),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _charcoal,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _grey,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _charcoal.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tip.icon, size: 18, color: _charcoal),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tip.text,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
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
