import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../components/app_circle_button.dart';
import '../ui/app_theme.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/adaptive/app_platform.dart';

class PlusView extends StatelessWidget {
  const PlusView({super.key});

  static const _green = AppColors.goStrong;
  static const _charcoal = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: isCupertino(context)
          ? AppNavBar(
              title: 'GASOLINAHAN PLUS',
              leading: AppCircleButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                iconSize: 20,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : AppBar(
              backgroundColor: const Color(0xFFF4F6F9),
              elevation: 0,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: AppCircleButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  iconSize: 20,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              centerTitle: true,
              title: const Text(
                'GASOLINAHAN PLUS',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 40,
                color: _green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Plus',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock premium features and support the community.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            _buildPlanCard(
              title: 'GASOLINAHAN FREE',
              price: '₱0',
              period: 'forever',
              features: [
                'Basic price reports',
                'View nearby stations',
                'Community leaderboard',
              ],
              isCurrent: true,
            ),
            const SizedBox(height: 16),
            _buildPlanCard(
              title: 'GASOLINAHAN PLUS',
              price: '₱99',
              period: '/month',
              features: [
                'Ad-free experience',
                'Price change alerts',
                'Detailed price history charts',
                'Priority report verification',
                'Exclusive badges',
              ],
              isHighlighted: true,
            ),
            const SizedBox(height: 16),
            _buildPlanCard(
              title: 'GASOLINAHAN GOLD',
              price: '₱899',
              period: '/year',
              features: [
                'Everything in Plus',
                'Save 25% vs monthly',
                'Gold profile badge',
                'Early access to new features',
                'Route fuel planner',
              ],
              isHighlighted: true,
              accentColor: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    bool isCurrent = false,
    bool isHighlighted = false,
    Color accentColor = _green,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: accentColor, width: 2)
            : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _charcoal,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _charcoal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _charcoal,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  period,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: isHighlighted ? accentColor : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    f,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isHighlighted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: _SubscribeButton(accentColor: accentColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  final Color accentColor;

  const _SubscribeButton({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoButton(
        onPressed: () {},
        padding: EdgeInsets.zero,
        color: accentColor,
        borderRadius: BorderRadius.circular(14),
        child: const Text(
          'Subscribe',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(
        'Subscribe',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
