import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../components/app_logo.dart';
import '../components/app_primary_button.dart';
import '../services/onboarding_prefs.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/app_theme.dart';
import 'welcome_vignettes.dart';

const _pageAnimation = Duration(milliseconds: 300);

class _WelcomePage {
  final String title;
  final String body;
  final Widget illustration;

  const _WelcomePage({
    required this.title,
    required this.body,
    required this.illustration,
  });
}

const _pages = [
  _WelcomePage(
    title: 'Find the cheapest gas near you',
    body:
        'Live pump prices from drivers around you, right on the map. The '
        'cheapest station nearby is the black pin.',
    illustration: MapVignette(),
  ),
  _WelcomePage(
    title: 'Log every fill-up',
    body:
        'Pay, fill, log. Gasolinahan works out how far each tank went, your '
        'km per liter and what every kilometer costs.',
    illustration: FillUpVignette(),
  ),
  _WelcomePage(
    title: 'Know what your driving costs',
    body:
        'See a month of fuel at your pace, your best and worst tanks, and '
        'which brand goes further in your own car.',
    illustration: BrandsVignette(),
  ),
  _WelcomePage(
    title: 'Prices change every Tuesday',
    body:
        'When a station\'s prices are from last week, snap its price board. '
        'One photo keeps prices fresh for everyone.',
    illustration: TuesdayVignette(),
  ),
];

/// Welcome tour shown before sign-in to new users and to people who haven't
/// opened the app in a while. Skip or finish goes on to [nextRoute].
class WelcomeView extends StatefulWidget {
  final String nextRoute;
  final OnboardingPrefs? prefs;

  const WelcomeView({super.key, required this.nextRoute, this.prefs});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  final _controller = PageController();
  late final OnboardingPrefs _prefs = widget.prefs ?? OnboardingPrefs();
  int _page = 0;
  bool _neverShowAgain = false;
  bool _leaving = false;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    if (_neverShowAgain) await _prefs.neverShowAgain();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, widget.nextRoute);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(duration: _pageAnimation, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const AppLogo(size: 32),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Skip the welcome tour',
                    excludeSemantics: true,
                    onTap: _finish,
                    child: AppTextButton(
                      onPressed: _finish,
                      foregroundColor: AppColors.ink,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _PageBody(page: _pages[i]),
              ),
            ),
            Semantics(
              label: 'Page ${_page + 1} of ${_pages.length}',
              excludeSemantics: true,
              child: SmoothPageIndicator(
                controller: _controller,
                count: _pages.length,
                effect: const ExpandingDotsEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 6,
                  activeDotColor: AppColors.ink,
                  dotColor: AppColors.divider,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CheckboxListTile(
                value: _neverShowAgain,
                onChanged: (v) => setState(() => _neverShowAgain = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.ink,
                dense: true,
                title: const Text(
                  "Don't show this again",
                  style: TextStyle(fontSize: 14, color: AppColors.text),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: AppPrimaryButton(
                label: _isLast ? 'Get started' : 'Next',
                trailingIcon: _isLast ? null : Icons.arrow_forward,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  final _WelcomePage page;

  const _PageBody({required this.page});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          page.illustration,
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(page.title, style: text.headlineSmall),
          ),
          const SizedBox(height: 10),
          Text(
            page.body,
            style: text.bodyLarge?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
