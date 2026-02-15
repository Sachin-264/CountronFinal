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

  // 📌 UPDATED: Added awaits for both tab and device
  Future<void> _restoreState() async {
    // 1. Restore Active Tab
    final savedTab = await SessionManager.getSavedTab(); // Await here
    if (savedTab.isNotEmpty) {
      try {
        _activeScreen = ClientScreen.values.firstWhere(
              (e) => e.toString().split('.').last == savedTab,
          orElse: () => ClientScreen.devices,
        );
      } catch (_) {}
    }

    // 2. Restore Selected Device
    final savedDevice = await SessionManager.getSelectedDevice(); // Await here
    if (savedDevice != null) {
      if (mounted) {
        Provider.of<ClientProvider>(context, listen: false).restoreDevice(savedDevice);
      }
    }

    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }

  // 📌 UPDATED: Added async/await
  Future<void> _onScreenSelected(ClientScreen screen) async {
    setState(() => _activeScreen = screen);
    await SessionManager.saveCurrentTab(screen.toString().split('.').last);
  }

  void _goToDeviceConfig(Map<String, dynamic> selectedDevice) {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    provider.selectDevice(selectedDevice);
    // You might want to save this to SessionManager here too
    SessionManager.saveSelectedDevice(selectedDevice);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<ClientProvider>(
        builder: (context, provider, child) {
          final isDeviceSelected = provider.selectedDeviceRecNo != null;

          if (isDeviceSelected) {
            return ClientLayout(
              activeScreen: _activeScreen,
              onScreenSelected: _onScreenSelected,
              userData: widget.userData,
              child: const SizedBox(),
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