import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_wrapper.dart';
import 'screens/order_form_screen.dart';
import 'screens/order_tracker_screen.dart';

import 'providers/notification_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/announcement_provider.dart';
import 'screens/notification_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';

import 'providers/gallon_provider.dart';
import 'services/local_notification_service.dart';
import 'theme/premium_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qxruxonusvoxshuwxrah.supabase.co',
    publishableKey: 'sb_publishable_MbMRR6syNwtezcWMke6yXw_Y1cozFRo',
  );

  await LocalNotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()..initializeFromSupabase()),
        ChangeNotifierProvider(create: (_) => GallonProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()..fetchAnnouncements()),
      ],
      child: const AquaSyncApp(),
    ),
  );
}

class AquaSyncApp extends StatelessWidget {
  const AquaSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AquaSync Customer App',
      debugShowCheckedModeBanner: false,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: AquaTheme.dark,
      theme: AquaTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainWrapper(),
        '/order': (context) => const OrderFormScreen(),
        '/tracker': (context) => const OrderTrackerScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}
