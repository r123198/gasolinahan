import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/fill_up_viewmodel.dart';
import 'viewmodels/report_viewmodel.dart';
import 'viewmodels/trip_viewmodel.dart';
import 'views/splash_view.dart';
import 'views/sign_in_view.dart';
import 'views/sign_up_view.dart';
import 'views/dashboard_view.dart';
import 'views/profile_view.dart';
import 'views/report_view.dart';
import 'views/report_form_view.dart';
import 'views/success_view.dart';
import 'views/error_view.dart';
import 'views/seed_view.dart';
import 'ui/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => ReportViewModel()),
        ChangeNotifierProvider(create: (_) => FillUpViewModel()..load()),
        ChangeNotifierProvider(create: (_) => TripViewModel()),
      ],
      child: MaterialApp(
        title: 'Gasolinahan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashView(),
          '/login': (context) => const SignInView(),
          '/register': (context) => const SignUpView(),
          '/dashboard': (context) => const DashboardView(),
          '/profile': (context) => const ProfileView(),
          '/report': (context) => const ReportView(),
          '/report-form': (context) => const ReportFormView(),
          '/success': (context) => const SuccessView(),
          '/error': (context) => const ErrorView(),
          '/seed': (context) => const SeedView(),
        },
      ),
    );
  }
}
