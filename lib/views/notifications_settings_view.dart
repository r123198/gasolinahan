import 'package:flutter/material.dart';
import '../components/app_circle_button.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/app_theme.dart';

class NotificationsSettingsView extends StatefulWidget {
  const NotificationsSettingsView({super.key});

  @override
  State<NotificationsSettingsView> createState() =>
      _NotificationsSettingsViewState();
}

class _NotificationsSettingsViewState extends State<NotificationsSettingsView> {
  bool _priceAlerts = true;
  bool _reportUpdates = true;
  bool _communityUpdates = false;
  bool _promotions = false;

  static const _charcoal = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: isCupertino(context)
          ? AppNavBar(
              title: 'Notifications',
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
                'Notifications',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Push Notifications',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.trending_down_rounded,
              title: 'Price Drop Alerts',
              subtitle:
                  'Get notified when prices drop at your favorite stations',
              value: _priceAlerts,
              onChanged: (v) => setState(() => _priceAlerts = v),
            ),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.fact_check_rounded,
              title: 'Report Updates',
              subtitle: 'When your submitted reports are verified',
              value: _reportUpdates,
              onChanged: (v) => setState(() => _reportUpdates = v),
            ),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.groups_rounded,
              title: 'Community Updates',
              subtitle: 'New stations added, leaderboard changes',
              value: _communityUpdates,
              onChanged: (v) => setState(() => _communityUpdates = v),
            ),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.local_offer_rounded,
              title: 'Promotions',
              subtitle: 'Special offers and Gasolinahan Plus deals',
              value: _promotions,
              onChanged: (v) => setState(() => _promotions = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _charcoal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: _charcoal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }
}
