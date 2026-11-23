import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/splash_gate.dart';
import 'services/demo_parking_repository.dart';
import 'services/parking_repository.dart';
import 'services/supabase_parking_repository.dart';

class QuickParkingApp extends StatelessWidget {
  const QuickParkingApp({
    super.key,
    required this.supabaseReady,
    this.bootstrapError,
  });

  final bool supabaseReady;
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ParkingRepository>(
          create: (_) => supabaseReady
              ? SupabaseParkingRepository(client: Supabase.instance.client)
              : DemoParkingRepository(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<ParkingRepository, AuthProvider>(
          create: (_) => AuthProvider(),
          update: (_, repository, provider) => provider!..bind(repository),
        ),
        ChangeNotifierProxyProvider<ParkingRepository, CustomerBookingProvider>(
          create: (_) => CustomerBookingProvider(),
          update: (_, repository, provider) => provider!..bind(repository),
        ),
        ChangeNotifierProvider(create: (_) => AdminConsoleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'QuickParking',
            themeMode: theme.themeMode,
            theme: buildQuickParkingTheme(Brightness.light),
            darkTheme: buildQuickParkingTheme(Brightness.dark),
            home: bootstrapError == null
                ? const SplashGate()
                : SupabaseSetupRequiredScreen(error: bootstrapError),
          );
        },
      ),
    );
  }
}
