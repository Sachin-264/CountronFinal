import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import Screens
import '../loginUI.dart';
import '../AdminScreens/admin_shell.dart';
import '../ClientScreen/ClientShell.dart';
import '../provider/client_provider.dart';

class AppRoutes {
  // --- Route Names ---
  static const String login = '/login';
  static const String admin = '/admin';
  static const String client = '/client';

  // --- Route Map ---
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),

      admin: (context) => const AdminShell(),

      client: (context) {
        // Safety: If provider is empty (direct URL access), redirect to login
        final clientData = Provider.of<ClientProvider>(context, listen: false).clientData;
        if (clientData == null) {
          return const LoginScreen();
        }
        return ClientShell(userData: clientData);
      },
    };
  }
}