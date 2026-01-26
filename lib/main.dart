import 'package:countron_app/provider/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/admin_provider.dart';
import 'provider/client_provider.dart';
import 'theme/app_theme.dart';

// Import the new Routes file
import 'routes/app_routes.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
      ],
      child: const CountronApp(),
    ),
  );
}

class CountronApp extends StatefulWidget {
  const CountronApp({super.key});

  @override
  State<CountronApp> createState() => _CountronAppState();
}

class _CountronAppState extends State<CountronApp> {
  String _initialRoute = AppRoutes.login;

  @override
  void initState() {
    super.initState();
    _checkSessionRestoration();
  }

  void _checkSessionRestoration() {
    if (SessionManager.hasSession()) {
      final role = SessionManager.getRole();
      final userData = SessionManager.getUserData();

      // Restore Providers
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (role == 'Admin') {
          Provider.of<AdminProvider>(context, listen: false).setAdminData(userData);
          _setRoute(AppRoutes.admin);
        } else if (role == 'Client') {
          Provider.of<ClientProvider>(context, listen: false).setClientData(userData);
          _setRoute(AppRoutes.client);
        }
      });
    }
  }

  void _setRoute(String route) {
    setState(() {
      _initialRoute = route;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countron Smart Logger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // --- USE THE ROUTE MAP ---
      initialRoute: _initialRoute,
      routes: AppRoutes.getRoutes(),
    );
  }
}