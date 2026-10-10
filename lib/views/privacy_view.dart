import 'package:flutter/material.dart';
import '../components/app_circle_button.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/adaptive/app_platform.dart';
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
              'Privacy Policy',
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                  'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
                  'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
                  'nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in '
                  'reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla '
                  'pariatur. Excepteur sint occaecat cupidatat non proident, sunt in '
                  'culpa qui officia deserunt mollit anim id est laborum.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data Collection',
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                  'Praesent commodo cursus magna, vel scelerisque nisl consectetur et. '
                  'Vivamus sagittis lacus vel augue laoreet rutrum faucibus dolor auctor. '
                  'Nullam quis risus eget urna mollis ornare vel eu leo. '
                  'Cras mattis consectetur purus sit amet fermentum.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data Sharing',
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                  'Maecenas sed diam eget risus varius blandit sit amet non magna. '
                  'Integer posuere erat a ante venenatis dapibus posuere velit aliquet. '
                  'Donec id elit non mi porta gravida at eget metus. '
                  'Fusce dapibus, tellus ac cursus commodo.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Security Measures',
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                  'Aenean lacinia bibendum nulla sed consectetur. '
                  'Cras justo odio, dapibus ut facilisis in, egestas eget quam. '
                  'Morbi leo risus, porta ac consectetur ac, vestibulum at eros. '
                  'Nulla vitae elit libero, a pharetra augue.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Your Rights',
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                  'Donec ullamcorper nulla non metus auctor fringilla. '
                  'Vestibulum id ligula porta felis euismod semper. '
                  'Cum sociis natoque penatibus et magnis dis parturient montes, '
                  'nascetur ridiculus mus.',
            ),
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
