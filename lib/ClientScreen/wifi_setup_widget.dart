// [UPDATE] lib/ClientScreen/wifi_setup_widget.dart
// FIXES:
//  - Batch Saving: Sends all 5 commands at once on Final Save
//  - Waits for WIFILIST::OK after sending 5 Wi-Fi configs
//  - Sends set_ALLDONE and waits for ALLDONE::OK before disconnecting
//  - Fixed password formatting typo (pass= instead of pass==)
//  - Empty slots explicitly get 'NODEF'
//  - UI updates locally instantly

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../provider/client_provider.dart';
import '../../theme/client_theme.dart';
import '../widgets/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _SavedWifi {
  int slot;   // 1-5 (Updated dynamically in UI)
  String ssid;
  String pass;
  _SavedWifi({required this.slot, required this.ssid, required this.pass});
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class WifiSetupWidget extends StatefulWidget {
  final VoidCallback onConnected;
  const WifiSetupWidget({super.key, required this.onConnected});

  @override
  State<WifiSetupWidget> createState() => _WifiSetupWidgetState();
}

class _WifiSetupWidgetState extends State<WifiSetupWidget> with WidgetsBindingObserver {

  // ── Flow step ──────────────────────────────────────────────────────────────
  int _flowStep = 0; // 0=Scan, 1=DeviceID, 2=Config

  // ── Wi-Fi scan state ───────────────────────────────────────────────────────
  List<WifiNetwork> _networks = [];
  String? _currentSSID;
  bool _isEnabled = false;
  bool _isScanning = false;
  Map<String, String> _savedPasswords = {};
  Timer? _wifiMonitorTimer;

  // ── Socket state ───────────────────────────────────────────────────────────
  Socket? _socket;
  final String _deviceIp = '192.168.4.1';
  final int _devicePort = 1336;
  Timer? _keepAliveTimer;
  bool _isSocketConnected = false;
  bool _isFetchingId = false;

  // ── Async Completers for Save Flow ─────────────────────────────────────────
  Completer<void>? _wifiListOkCompleter;
  Completer<void>? _allDoneOkCompleter;

  // ── Device ID ──────────────────────────────────────────────────────────────
  String _deviceId = '';

  // ── Saved WiFi list (from device) ─────────────────────────────────────────
  final List<_SavedWifi> _savedWifiList = [];
  bool _isFetchingWifi = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    print('🔵 [WiFi-Setup] Widget Initialized');
    WidgetsBinding.instance.addObserver(this);
    _loadSavedPasswords();
    _initializeWifi();
  }

  @override
  void dispose() {
    print('⚫ [WiFi-Setup] Disposing Widget');
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveTimer?.cancel();
    _socket?.destroy();
    _wifiMonitorTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeWifi();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WI-FI SCAN HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadSavedPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('wifi_pw_')) {
        _savedPasswords[key.replaceFirst('wifi_pw_', '')] = prefs.getString(key) ?? '';
      }
    }
  }

  Future<void> _initializeWifi() async {
    bool enabled = await WiFiForIoTPlugin.isEnabled();
    if (mounted) setState(() => _isEnabled = enabled);
    if (enabled) {
      await _getCurrentSSID();
      await _scanWifi();
      _startWifiMonitor();
    }
  }

  Future<void> _getCurrentSSID() async {
    final ssid = await WiFiForIoTPlugin.getSSID();
    if (mounted) setState(() => _currentSSID = (ssid == '<unknown ssid>' ? null : ssid));
  }

  Future<void> _scanWifi() async {
    if (!mounted) return;
    setState(() => _isScanning = true);
    try {
      List<WifiNetwork> results = await WiFiForIoTPlugin.loadWifiList();
      results.sort((a, b) {
        if (a.ssid == _currentSSID) return -1;
        if (b.ssid == _currentSSID) return 1;
        return (b.level ?? 0).compareTo(a.level ?? 0);
      });
      if (mounted) setState(() => _networks = results);
    } catch (e) {
      print('❌ [WiFi-Setup] SCAN ERROR: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _startWifiMonitor() {
    _wifiMonitorTimer?.cancel();
    _wifiMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isEnabled) return;
      final ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid != _currentSSID && mounted) _getCurrentSSID();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONNECT TO HOTSPOT
  // ══════════════════════════════════════════════════════════════════════════

  void _handleNetworkTap(WifiNetwork net) {
    final ssid = net.ssid ?? 'Unknown';
    if (ssid == _currentSSID) {
      _enterConfigMode();
      return;
    }
    final isOpen = !(net.capabilities?.toUpperCase().contains('WPA') == true ||
        net.capabilities?.toUpperCase().contains('WEP') == true);
    if (isOpen) {
      _connectToWifi(ssid, '', security: NetworkSecurity.NONE);
    } else if (_savedPasswords.containsKey(ssid)) {
      _connectToWifi(ssid, _savedPasswords[ssid]!, security: NetworkSecurity.WPA);
    } else {
      _showPasswordDialog(ssid);
    }
  }

  Future<void> _connectToWifi(String ssid, String password,
      {NetworkSecurity security = NetworkSecurity.WPA}) async {
    try {
      await WiFiForIoTPlugin.disconnect();
      bool result = await WiFiForIoTPlugin.connect(ssid,
          password: password.isEmpty ? null : password,
          security: security,
          joinOnce: true);
      if (result) {
        if (password.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('wifi_pw_$ssid', password);
          _savedPasswords[ssid] = password;
        }
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await Future.delayed(const Duration(seconds: 3));
        await _initializeWifi();
        _enterConfigMode();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection Failed: $e')));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SOCKET & PARSING
  // ══════════════════════════════════════════════════════════════════════════

  void _enterConfigMode() {
    if (_deviceId.isNotEmpty && _flowStep >= 1) {
      setState(() { _flowStep = 1; });
      _connectSocket();
      return;
    }
    setState(() { _flowStep = 1; _isFetchingId = true; _deviceId = ''; });
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    if (_socket != null) return;
    try {
      _socket = await Socket.connect(_deviceIp, _devicePort, timeout: const Duration(seconds: 5));
      if (mounted) setState(() => _isSocketConnected = true);
      _startHeartbeat();

      _socket!.listen(
            (Uint8List data) {
          final text = utf8.decode(data, allowMalformed: true).trim();
          for (final line in text.split('\n')) {
            if (line.trim().isNotEmpty) _handleResponse(line.trim());
          }
        },
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
      );
      await _sendCmd('get_DEVICEID');
    } catch (e) {
      if (mounted) setState(() { _isSocketConnected = false; _isFetchingId = false; });
    }
  }

  void _onDisconnect() {
    _keepAliveTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    if (mounted) setState(() { _isSocketConnected = false; _isFetchingId = false; _isFetchingWifi = false; });
  }

  void _startHeartbeat() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_socket != null && _isSocketConnected) _sendCmd('KEEP_ALIVE');
    });
  }

  Future<void> _sendCmd(String cmd) async {
    if (_socket == null) return;
    try {
      _socket!.write('$cmd\r\n');
    } catch (e) {
      _onDisconnect();
    }
  }

  void _handleResponse(String line) {
    print('📩 [RECV]: $line');

    if (line.contains('DEVICEID::')) {
      final id = line.split('::').last.trim();
      if (_deviceId == id) return;
      if (mounted) setState(() { _deviceId = id; _isFetchingId = false; });
      return;
    }

    if (line.contains('WIFILIST::OK')) {
      if (_wifiListOkCompleter != null && !_wifiListOkCompleter!.isCompleted) {
        print('✅ [RECV]: Received WIFILIST::OK');
        _wifiListOkCompleter!.complete();
      }
      return;
    }

    if (line.contains('ALLDONE::OK')) {
      if (_allDoneOkCompleter != null && !_allDoneOkCompleter!.isCompleted) {
        print('✅ [RECV]: Received ALLDONE::OK');
        _allDoneOkCompleter!.complete();
      }
      return;
    }

    if (line.startsWith('WIFILIST::')) {
      final rawList = line.replaceFirst('WIFILIST::', '');
      final regex = RegExp(r'ssid=(.*?);pass==?(.*?);');
      final matches = regex.allMatches(rawList);

      final List<_SavedWifi> parsedList = [];
      int slotCounter = 1;

      for (final match in matches) {
        if (slotCounter > 5) break;
        String ssid = match.group(1) ?? '';
        String pass = match.group(2) ?? '';

        if (ssid.isNotEmpty && ssid != 'NODEF') {
          parsedList.add(_SavedWifi(slot: slotCounter, ssid: ssid, pass: pass));
          slotCounter++; // Only increment slot if it's a valid network
        }
      }

      if (mounted) {
        setState(() {
          _savedWifiList.clear();
          _savedWifiList.addAll(parsedList);
          _isFetchingWifi = false;
        });
        print('✅ Parsed ${_savedWifiList.length} valid networks.');
      }
      return;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL UI ACTIONS (ADD/EDIT/DELETE)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchWifiList() async {
    if (mounted) setState(() { _isFetchingWifi = true; _savedWifiList.clear(); });
    await _sendCmd('get_WIFILIST');
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _isFetchingWifi = false);
  }

  void _onNextPressed() {
    setState(() { _flowStep = 2; _isFetchingWifi = true; _savedWifiList.clear(); });
    _fetchWifiList();
  }

  void _reassignSlots() {
    // Ensures UI slots are always 1, 2, 3... without gaps
    for (int i = 0; i < _savedWifiList.length; i++) {
      _savedWifiList[i].slot = i + 1;
    }
  }

  void _showAddWifiDialog() {
    if (_savedWifiList.length >= 5) return;
    _showWifiInputSheet(title: 'Add Wi-Fi', isAdd: true);
  }

  void _showEditDialog(_SavedWifi wifi) {
    _showWifiInputSheet(
        title: 'Edit Wi-Fi',
        isAdd: false,
        targetWifi: wifi,
        initialSsid: wifi.ssid,
        initialPass: wifi.pass
    );
  }

  void _showWifiInputSheet({required String title, required bool isAdd, _SavedWifi? targetWifi, String? initialSsid, String? initialPass}) {
    final ssidCtrl = TextEditingController(text: initialSsid);
    final passCtrl = TextEditingController(text: initialPass);
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ssidCtrl,
              decoration: InputDecoration(labelText: 'Network Name (SSID)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ClientTheme.textLight))),
            ElevatedButton(
              onPressed: () {
                final ssid = ssidCtrl.text.trim();
                final pass = passCtrl.text.trim();
                if (ssid.isEmpty) return;

                setState(() {
                  if (isAdd) {
                    _savedWifiList.add(_SavedWifi(slot: 0, ssid: ssid, pass: pass));
                  } else if (targetWifi != null) {
                    targetWifi.ssid = ssid;
                    targetWifi.pass = pass;
                  }
                  _reassignSlots(); // Clean up slots
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Locally'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(_SavedWifi wifi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Wi-Fi?'),
        content: Text('Remove "${wifi.ssid}" from your configuration list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ClientTheme.textLight))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _savedWifiList.remove(wifi);
                _reassignSlots(); // Shift remaining networks up
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FINAL BATCH SAVE & API SYNC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleSaveAndNext() async {
    if (_deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Device ID received from hardware.')));
      return;
    }

    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final int oldRecNo = clientProvider.selectedDeviceRecNo ?? 0;
    if (oldRecNo == 0) return;

    setState(() => _isSyncing = true);

    try {
      // ── 1. SEND ALL 5 BATCH COMMANDS ──
      print('🚀 [Batch Save] Sending 5 commands to device...');
      _wifiListOkCompleter = Completer<void>(); // Initialize completer

      for (int i = 1; i <= 5; i++) {
        String cmd;
        int listIndex = i - 1;

        if (listIndex < _savedWifiList.length) {
          // Send actual user network (Fixed pass= typo)
          final w = _savedWifiList[listIndex];
          cmd = 'set_WIFI$i::ssid=${w.ssid};pass=${w.pass};';
        } else {
          // Fill empty slots with NODEF (Fixed pass= typo)
          cmd = 'set_WIFI$i::ssid=NODEF;pass=NODEF;';
        }

        print('📤 [Batch Save] $cmd');
        await _sendCmd(cmd);
        // Brief delay so device buffer isn't overwhelmed
        await Future.delayed(const Duration(milliseconds: 300));
      }

      print('⏳ [Batch Save] Waiting for WIFILIST::OK...');
      await _wifiListOkCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout waiting for WIFILIST::OK response'),
      );
      print('✅ [Batch Save] Device confirmed WIFILIST::OK');

      // ── 2. SEND ALLDONE COMMAND ──
      _allDoneOkCompleter = Completer<void>(); // Initialize completer
      print('📤 [Batch Save] Sending set_ALLDONE...');
      await _sendCmd('set_ALLDONE');

      print('⏳ [Batch Save] Waiting for ALLDONE::OK...');
      await _allDoneOkCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout waiting for ALLDONE::OK response'),
      );
      print('✅ [Batch Save] Device confirmed ALLDONE::OK');

      // ── 3. DISCONNECT & PROCEED TO INTERNET API SYNC ──
      _socket?.destroy(); _socket = null;
      await WiFiForIoTPlugin.disconnect();
      await WiFiForIoTPlugin.forceWifiUsage(false);
      await Future.delayed(const Duration(seconds: 6));

      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) throw Exception('No internet.');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/device_id_update_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'UPDATE_DEVICE_ID', 'OldRecNo': oldRecNo, 'NewRecNo': int.parse(_deviceId)}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          await clientProvider.updateAfterHardwareSync(int.parse(_deviceId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Configured Successfully!'), backgroundColor: ClientTheme.success));
            await Future.delayed(const Duration(milliseconds: 1200));
            widget.onConnected();
          }
        } else {
          throw Exception(data['message'] ?? 'Update failed');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: ClientTheme.error));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
      _wifiListOkCompleter = null;
      _allDoneOkCompleter = null;
    }
  }


  // ── Advanced: Reset Memory ─────────────────────────────────────────────────
  void _showAdvancedSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Advanced Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Use these options only if instructed by support.', style: TextStyle(color: ClientTheme.textLight, fontSize: 13)),
          const SizedBox(height: 24),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Icon(Iconsax.refresh, color: Colors.red.shade600),
            ),
            title: const Text('Reset Device Memory', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Clears all stored data on the device.'),
            trailing: const Icon(Iconsax.arrow_right_3),
            onTap: () {
              Navigator.pop(ctx);
              _confirmResetMemory();
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _confirmResetMemory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Iconsax.warning_2, color: Colors.orange.shade600), const SizedBox(width: 8), const Text('Reset Memory?')]),
        content: const Text('This will erase all saved data on the device. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendCmd('set_RESETMEM;');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset command sent to device.'), backgroundColor: Colors.orange));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PASSWORD DIALOG
  // ══════════════════════════════════════════════════════════════════════════

  void _showPasswordDialog(String ssid) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.lock, size: 18), const SizedBox(width: 8), Text('Connect to $ssid', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        content: TextField(
          controller: ctrl, obscureText: true, autofocus: true,
          decoration: InputDecoration(hintText: 'Enter Password', filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ClientTheme.textLight))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _connectToWifi(ssid, ctrl.text); },
            style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ClientTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          if (!_isEnabled)
            _buildWifiOffState()
          else if (_flowStep == 0)
            Expanded(child: _buildScanList())
          else if (_flowStep == 1)
              Expanded(child: _buildDeviceIdStep())
            else
              Expanded(child: _buildWifiConfigStep()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    String title = 'Setup Required';
    String status = 'Wi-Fi is Off';
    Color statusColor = ClientTheme.error;
    if (_isEnabled) {
      if (_flowStep == 0) { title = 'Connect to Device'; status = 'Scan nearby hotspots'; statusColor = Colors.orange; }
      if (_flowStep == 1) { title = 'Device Detected'; status = _isSocketConnected ? 'Connected' : 'Disconnected'; statusColor = _isSocketConnected ? ClientTheme.success : Colors.red; }
      if (_flowStep == 2) { title = 'Wi-Fi Configuration'; status = _isSocketConnected ? 'Connected' : 'Disconnected'; statusColor = _isSocketConnected ? ClientTheme.success : Colors.red; }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClientTheme.textDark)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: ClientTheme.textLight, fontSize: 12)),
              ]),
            ]),
          ),
          if (_flowStep == 0 && _isEnabled)
            IconButton(onPressed: _scanWifi, icon: _isScanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ClientTheme.primaryColor)) : Icon(Iconsax.refresh, color: ClientTheme.primaryColor)),
          if (_flowStep == 2)
            IconButton(icon: Icon(Iconsax.setting_4, color: ClientTheme.primaryColor.withOpacity(0.8)), tooltip: 'Advanced Settings', onPressed: _showAdvancedSettings),
          IconButton(
            icon: const Icon(Iconsax.close_circle, color: ClientTheme.error),
            onPressed: () { _socket?.destroy(); Navigator.of(context).pop(); },
          ),
        ],
      ),
    );
  }

  Widget _buildWifiOffState() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const Spacer(flex: 2),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: ClientTheme.error.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Iconsax.wifi_square, size: 40, color: ClientTheme.error.withOpacity(0.8)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1.5.seconds),
          const SizedBox(height: 24),
          Text('Turn On Wi-Fi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ClientTheme.textDark)),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity, height: 56,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [ClientTheme.primaryColor, ClientTheme.primaryColor.withOpacity(0.8)])),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true),
                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Iconsax.flash_1, color: Colors.white, size: 22), SizedBox(width: 10), Text('ENABLE WI-FI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 15))])),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _initializeWifi, child: const Text('I have already enabled it', style: TextStyle(fontSize: 13, decoration: TextDecoration.underline))),
          const Spacer(flex: 1),
        ]),
      ),
    );
  }

  Widget _buildScanList() {
    if (_networks.isEmpty && !_isScanning) {
      return Center(child: Text('No networks found', style: TextStyle(color: ClientTheme.textLight)));
    }
    return RefreshIndicator(
      onRefresh: _scanWifi,
      color: ClientTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _networks.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemBuilder: (context, i) {
          final net = _networks[i];
          final isCurrent = net.ssid == _currentSSID && _currentSSID != null;
          return AnimatedContainer(
            duration: 300.ms,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isCurrent ? ClientTheme.primaryColor.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isCurrent ? ClientTheme.primaryColor : Colors.grey.shade200, width: isCurrent ? 1.5 : 1),
            ),
            child: ListTile(
              leading: Icon(Iconsax.wifi, color: isCurrent ? ClientTheme.primaryColor : Colors.grey.shade600),
              title: Text(net.ssid ?? 'Hidden Network'),
              subtitle: isCurrent ? const Text('Connected', style: TextStyle(color: ClientTheme.success, fontSize: 12)) : null,
              trailing: isCurrent ? const Icon(Icons.check, color: ClientTheme.success) : const Icon(Iconsax.arrow_right_3),
              onTap: () => _handleNetworkTap(net),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceIdStep() {
    bool hasId = !_isFetchingId && _deviceId.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              border: Border.all(color: hasId ? ClientTheme.success.withOpacity(0.3) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                if (_isFetchingId)
                  Container(
                    width: 80, height: 80,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ClientTheme.primaryColor.withOpacity(0.1)),
                    child: const CircularProgressIndicator(strokeWidth: 3, color: ClientTheme.primaryColor),
                  )
                else
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: ClientTheme.success),
                    child: const Icon(Iconsax.verify, color: Colors.white, size: 40),
                  ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),

                const SizedBox(height: 24),
                Text(_isFetchingId ? 'Communicating...' : 'Device Verified', style: TextStyle(color: ClientTheme.textLight, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(
                  hasId ? _deviceId : 'Waiting...',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: ClientTheme.textDark, letterSpacing: 2),
                ).animate().fadeIn(),
              ],
            ),
          ),
          const SizedBox(height: 40),
          if (hasId)
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                onPressed: _onNextPressed,
                icon: const Icon(Iconsax.wifi, color: Colors.white),
                label: const Text('CONFIGURE WI-FI', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().slideY(begin: 0.2, duration: 400.ms).fadeIn(),
          if (!_isFetchingId && _deviceId.isEmpty)
            Column(children: [
              const Text('Could not retrieve Device ID.', style: TextStyle(color: Colors.red)),
              TextButton(
                  onPressed: () async { setState(() => _isFetchingId = true); await _sendCmd('get_DEVICEID'); },
                  child: const Text('Try Again')
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildWifiConfigStep() {
    final canAdd = _savedWifiList.length < 5;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(children: [
          Icon(Iconsax.wifi, color: ClientTheme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Text('Saved Networks (${_savedWifiList.length}/5)', style: TextStyle(color: ClientTheme.textDark, fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: _isFetchingWifi
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: ClientTheme.primaryColor, strokeWidth: 2), const SizedBox(height: 12), Text('Loading saved networks...', style: TextStyle(color: ClientTheme.textLight))]))
            : ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ..._savedWifiList.map((wifi) => _buildWifiTile(wifi)),
            const SizedBox(height: 8),
            Opacity(
              opacity: canAdd ? 1.0 : 0.4,
              child: InkWell(
                onTap: canAdd ? _showAddWifiDialog : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: canAdd ? ClientTheme.primaryColor.withOpacity(0.4) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                    color: canAdd ? ClientTheme.primaryColor.withOpacity(0.03) : Colors.grey.shade50,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Iconsax.add, color: canAdd ? ClientTheme.primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    Text(canAdd ? 'Add Wi-Fi Network' : 'Maximum 5 Networks Reached', style: TextStyle(color: canAdd ? ClientTheme.primaryColor : Colors.grey, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            onPressed: _isSyncing ? null : _handleSaveAndNext,
            icon: _isSyncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Iconsax.save_2, color: Colors.white),
            label: Text(_isSyncing ? 'SYNCING...' : 'SAVE & CONFIGURE CHANNELS', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ),
    ]);
  }

  Widget _buildWifiTile(_SavedWifi wifi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ClientTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(Iconsax.wifi, color: ClientTheme.primaryColor, size: 20)),
        title: Text(wifi.ssid, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Slot ${wifi.slot} · Password saved', style: TextStyle(fontSize: 11, color: ClientTheme.textLight)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Iconsax.edit, color: Colors.blue.shade400, size: 20),
              onPressed: () => _showEditDialog(wifi),
            ),
            IconButton(
              icon: Icon(Iconsax.trash, color: Colors.red.shade400, size: 20),
              onPressed: () => _showDeleteConfirm(wifi),
            ),
          ],
        ),
      ),
    );
  }
}