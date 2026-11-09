import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
import 'models/app_access.dart';
import 'services/database_setup.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/fill_up_nudge_viewmodel.dart';
import 'viewmodels/fill_up_viewmodel.dart';
import 'viewmodels/report_viewmodel.dart';
import 'viewmodels/trip_viewmodel.dart';
import 'views/splash_view.dart';
import 'views/welcome_view.dart';
import 'views/sign_in_view.dart';
import 'views/sign_up_view.dart';
import 'views/dashboard_view.dart';
import 'views/report_view.dart';
import 'views/report_form_view.dart';
import 'views/success_view.dart';
import 'views/error_view.dart';
import 'views/seed_view.dart';
import 'ui/app_theme.dart';
import 'ui/web_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureLocalDatabase();
  final flavor = flavorForBuild(appFlavor, isWeb: kIsWeb);
  await Firebase.initializeApp(options: firebaseOptionsFor(flavor));
  runApp(MyApp(flavor: flavor));
}

/// Lets a mouse drag lists and chip rows too, which browsers need: desktop
/// users have no touch and a wheel only scrolls one way.
class _WebScrollBehavior extends MaterialScrollBehavior {
  const _WebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Refreshing a page always restarts at the splash, which restores the
/// session and picks the landing page; screens further in rely on state
/// that a reload has lost. Named routes then keep browser history working.
List<Route<dynamic>> _webInitialRoutes(String _) => [
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/'),
    builder: (_) => const SplashView(),
  ),
];

/// A hand-edited address opens the map rather than an error.
Route<dynamic> _webUnknownRoute(RouteSettings _) => MaterialPageRoute<void>(
  settings: const RouteSettings(name: '/dashboard'),
  builder: (_) => const DashboardView(),
);

class MyApp extends StatelessWidget {
  final Flavor flavor;

  const MyApp({super.key, this.flavor = Flavor.prod});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => ReportViewModel()),
        ChangeNotifierProvider(
          create: (_) {
            final fillUps = FillUpViewModel();
            // On the web this waits for sign-in (see DashboardView): guests
            // shouldn't download the database just to view the map.
            if (!kIsWeb) unawaited(fillUps.load());
            return fillUps;
          },
        ),
        ChangeNotifierProvider(create: (_) => TripViewModel()),
        ChangeNotifierProvider(create: (_) => FillUpNudgeViewModel()),
      ],
      child: MaterialApp(
        title: 'Gasolinahan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        scrollBehavior: kIsWeb ? const _WebScrollBehavior() : null,
        onGenerateInitialRoutes: kIsWeb ? _webInitialRoutes : null,
        onUnknownRoute: kIsWeb ? _webUnknownRoute : null,
        builder: (context, child) {
          final label = flavor.label;
          if (label == null || child == null) return child ?? const SizedBox();
          return Banner(
            message: label,
            location: BannerLocation.topEnd,
            color: AppColors.accent,
            child: child,
          );
        },
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashView(),
          '/welcome': (context) => WelcomeView(
            nextRoute:
                ModalRoute.of(context)?.settings.arguments as String? ??
                '/login',
          ),
          '/login': (context) => const WebPageFrame(child: SignInView()),
          '/register': (context) => const WebPageFrame(child: SignUpView()),
          '/dashboard': (context) => DashboardView(
            goal: ModalRoute.of(context)?.settings.arguments as SignInGoal?,
          ),
          // The web's map is read-only: prices are reported from the phones.
          if (!kIsWeb) ...{
            '/report': (context) => const ReportView(),
            '/report-form': (context) => const ReportFormView(),
            '/success': (context) => const SuccessView(),
            '/error': (context) => const ErrorView(),
          },
          // Test-data seeder shows shared test credentials: debug builds only.
          if (kDebugMode) '/seed': (context) => const SeedView(),
        },
      ),
    );
  }
}
