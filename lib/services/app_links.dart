import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public pages on the Gasolinahan website (Firebase Hosting).
const _site = 'https://gasolinahan-e0917.web.app';

final privacyPolicyUrl = Uri.parse('$_site/privacy');
final termsUrl = Uri.parse('$_site/terms');
final deleteAccountUrl = Uri.parse('$_site/delete-account');
final supportUrl = Uri.parse('$_site/support');

const supportEmail = 'tibudan.rafael@gmail.com';

/// Opens [url] in the browser. Returns false when no app could open it, so
/// the caller can tell the user.
Future<bool> openLink(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } on PlatformException catch (e) {
    debugPrint('Could not open $url: ${e.code}');
    return false;
  }
}
