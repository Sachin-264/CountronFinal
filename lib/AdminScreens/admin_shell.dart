import 'package:flutter/material.dart';
import '../Mainlayout.dart';
import '../provider/session_manager.dart';
import '../routes/app_routes.dart';

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
  AppScreen _activeScreen = AppScreen.dashboard;

  @override
  void initState() {
    super.initState();
    _restoreActiveTab();
  }

  // 📌 UPDATED: Added async/await
  Future<void> _restoreActiveTab() async {
    final savedTab = await SessionManager.getSavedTab(); // Await the Future
    if (savedTab.isNotEmpty) {
      try {
        final screen = AppScreen.values.firstWhere(
              (e) => e.toString().split('.').last == savedTab,
          orElse: () => AppScreen.dashboard,
        );
        if (mounted) {
          setState(() => _activeScreen = screen);
        }
      } catch (e) {
        debugPrint("Error restoring tab: $e");
      }
    }
  }

  // 📌 UPDATED: Added async/await
  Future<void> _onScreenSelected(AppScreen screen) async {
    setState(() {
      _activeScreen = screen;
    });
    await SessionManager.saveCurrentTab(screen.toString().split('.').last);
  }

  // 📌 UPDATED: Added async/await
  Future<void> _performLogout() async {
    await SessionManager.clearSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
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