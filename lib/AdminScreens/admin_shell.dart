import 'package:flutter/material.dart';
import '../Mainlayout.dart';
import '../provider/session_manager.dart';
import '../routes/app_routes.dart'; // Import Routes

// Screens
import 'ChannelScreen/channelscreen.dart';
import 'ClientScreen/ClientScreen.dart';
import 'home_screen.dart';
import 'setting_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AppScreen _activeScreen = AppScreen.dashboard; // Default

  @override
  void initState() {
    super.initState();
    _restoreActiveTab(); // 2. Restore tab on load
  }

  // 📌 LOGIC: Restore the screen from Session Storage
  void _restoreActiveTab() {
    final savedTab = SessionManager.getSavedTab();
    if (savedTab.isNotEmpty) {
      try {
        // Convert string (e.g. "settings") back to Enum (AppScreen.settings)
        final screen = AppScreen.values.firstWhere(
              (e) => e.toString().split('.').last == savedTab,
          orElse: () => AppScreen.dashboard,
        );
        setState(() => _activeScreen = screen);
      } catch (e) {
        debugPrint("Error restoring tab: $e");
      }
    }
  }

  // 📌 LOGIC: Save the screen when clicked
  void _onScreenSelected(AppScreen screen) {
    setState(() {
      _activeScreen = screen;
    });
    // Save "dashboard", "clients", etc.
    SessionManager.saveCurrentTab(screen.toString().split('.').last);
  }

  void _performLogout() {
    SessionManager.clearSession();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  Widget _buildScreen() {
    switch (_activeScreen) {
      case AppScreen.dashboard: return const HomeScreen();
      case AppScreen.clients:   return const ClientScreen();
      case AppScreen.channels:  return const ChannelScreen();
      case AppScreen.settings:  return const SettingsScreen();
      default:                  return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      activeScreen: _activeScreen,
      onScreenSelected: _onScreenSelected,
      onLogout: _performLogout,
      child: _buildScreen(),
    );
  }
}