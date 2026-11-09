import 'package:flutter/material.dart';

import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';
import 'app_logo.dart';

/// What a guest sees over the map: who this is (linking to the about page)
/// and the way in to everything that needs an account.
class GuestMapBar extends StatelessWidget {
  final VoidCallback onAbout;
  final VoidCallback onSignIn;

  const GuestMapBar({super.key, required this.onAbout, required this.onSignIn});

  static const _shadow = [
    BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: _shadow,
          ),
          child: Semantics(
            link: true,
            label: 'About Gasolinahan',
            excludeSemantics: true,
            onTap: onAbout,
            child: AppTappable(
              onTap: onAbout,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 16, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLogo(size: 26),
                    SizedBox(width: 8),
                    Text(
                      'Gasolinahan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: onSignIn,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            shape: const StadiumBorder(),
          ),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}
