import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final flavor = flavorFrom(appFlavor);
  await Firebase.initializeApp(options: firebaseOptionsFor(flavor));
  runApp(MyApp(flavor: flavor));
}

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
        ChangeNotifierProvider(create: (_) => FillUpViewModel()..load()),
        ChangeNotifierProvider(create: (_) => TripViewModel()),
        ChangeNotifierProvider(create: (_) => FillUpNudgeViewModel()),
      ],
      child: MaterialApp(
        title: 'Gasolinahan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
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
          '/login': (context) => const SignInView(),
          '/register': (context) => const SignUpView(),
          '/dashboard': (context) => const DashboardView(),
          '/report': (context) => const ReportView(),
          '/report-form': (context) => const ReportFormView(),
          '/success': (context) => const SuccessView(),
          '/error': (context) => const ErrorView(),
          // Test-data seeder shows shared test credentials: debug builds only.
          if (kDebugMode) '/seed': (context) => const SeedView(),
        },
      ),
    );
  }
}
