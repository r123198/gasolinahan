import 'package:flutter/material.dart';
import '../components/app_circle_button.dart';
import '../components/app_list_tile.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/adaptive/app_platform.dart';
import '../services/app_links.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  static const _charcoal = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: isCupertino(context)
          ? AppNavBar(
              title: 'Privacy & Security',
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
                'Privacy & Security',
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
            _buildSection(
              'What leaves your phone',
              'Your name, email and optional profile photo, to run your '
                  'account. Your fill-up log, including where you logged it, so '
                  'it follows you to a new phone. Price reports with the '
                  "station's location. Station prices are shown to everyone "
                  'without your name.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'What stays on your phone',
              'Recorded trips and kilometers, fill-up photos, and the price '
                  'boards and odometers you scan. Text is read on your phone '
                  'and the photos are never uploaded.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Location and motion',
              'Location shows stations near you. With automatic trip '
                  'tracking on, location and motion are also used in the '
                  'background to record drives. You can turn that off in '
                  'Account. Map tiles and place names come from OpenStreetMap, '
                  'which receives the map area you look at.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'No ads, no tracking',
              "Gasolinahan has no ads or analytics, and doesn't sell or share "
                  'your data for advertising. Data is stored with Google '
                  'Firebase.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Your rights',
              'You can see and edit your details in Account, and delete '
                  'your account and its data any time from Account → Delete '
                  'account. Questions: $supportEmail',
            ),
            const SizedBox(height: 24),
            _LinkTile(label: 'Full privacy policy', url: privacyPolicyUrl),
            _LinkTile(label: 'Terms of use', url: termsUrl),
            _LinkTile(label: 'Help and support', url: supportUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final Uri url;

  const _LinkTile({required this.label, required this.url});

  Future<void> _open(BuildContext context) async {
    if (await openLink(url) || !context.mounted) return;
    showAppToast(context, "Couldn't open the browser. Visit $url");
  }

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      icon: Icons.open_in_new,
      title: label,
      onTap: () => _open(context),
    );
  }
}
