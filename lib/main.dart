import 'package:countron_app/provider/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/admin_provider.dart';
import 'provider/client_provider.dart';
import 'theme/app_theme.dart';

// Import the new Routes file
import 'routes/app_routes.dart';

void main() async {
  // Required to interact with native code (SharedPreferences) before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-fetch the initial route based on session
  String initialRoute = AppRoutes.login;
  String? role;
  Map<String, dynamic>? userData;

  if (await SessionManager.hasSession()) {
    role = await SessionManager.getRole();
    userData = await SessionManager.getUserData();

    if (role == 'Admin') {
      initialRoute = AppRoutes.admin;
    } else if (role == 'Client') {
      initialRoute = AppRoutes.client;
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = AdminProvider();
          if (role == 'Admin' && userData != null) {
            provider.setAdminData(userData);
          }
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = ClientProvider();
          if (role == 'Client' && userData != null) {
            provider.setClientData(userData);
          }
          return provider;
        }),
      ],
      child: CountronApp(initialRoute: initialRoute),
    ),
  );
}

class CountronApp extends StatelessWidget {
  final String initialRoute;

  const CountronApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countron Smart Logger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // --- USE THE ROUTE MAP ---
      initialRoute: initialRoute,
      routes: AppRoutes.getRoutes(),
    );
  }
}