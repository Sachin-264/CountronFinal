import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Clientlayout.dart';
import '../provider/session_manager.dart';
import 'device_selection_screen.dart';
import 'device_configure.dart' show DeviceConfigScreen, deviceConfigScreenKey;
import '../provider/client_provider.dart';

class ClientShell extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ClientShell({super.key, required this.userData});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  ClientScreen _activeScreen = ClientScreen.devices;
  bool _isRestoring = true;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  Future<void> _restoreState() async {
    // 1. Restore Active Tab (PRIORITY)
    final savedTab = SessionManager.getSavedTab();
    if (savedTab.isNotEmpty) {
      try {
        _activeScreen = ClientScreen.values.firstWhere(
              (e) => e.toString().split('.').last == savedTab,
          orElse: () => ClientScreen.devices,
        );
      } catch (_) {}
    }

    // 2. Restore Selected Device
    final savedDevice = SessionManager.getSelectedDevice();
    if (savedDevice != null) {
      // 🔴 FIX: Removed the line that forced screen to 'devices'.
      // Now it will stay on whatever screen was restored in step 1.

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ClientProvider>(context, listen: false).restoreDevice(savedDevice);
      });
    }

    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }

  // 🔴 UPDATED: Save tab to Session whenever it changes
  void _onScreenSelected(ClientScreen screen) {
    setState(() => _activeScreen = screen);
    SessionManager.saveCurrentTab(screen.toString().split('.').last);
  }

  void _goToDeviceConfig(Map<String, dynamic> selectedDevice) {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    provider.selectDevice(selectedDevice);
  }

  @override
  Widget build(BuildContext context) {
    // Show loader while restoring to prevent UI jumping
    if (_isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<ClientProvider>(
        builder: (context, provider, child) {
          final isDeviceSelected = provider.selectedDeviceRecNo != null;

          if (isDeviceSelected) {
            // We pass a simple Container or Loader as child because
            // ClientLayout now handles the actual screen switching logic internally.
            return ClientLayout(
              activeScreen: _activeScreen,
              onScreenSelected: _onScreenSelected,
              userData: widget.userData,
              child: const SizedBox(), // Layout handles the views
            );
          } else {
            return DeviceSelectionScreen(
              userData: widget.userData,
              onDeviceSelected: _goToDeviceConfig,
            );
          }
        }
    );
  }
}