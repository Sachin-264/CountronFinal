// lib/AdminScreen/admin_wifi_setup_widget.dart
// ADMIN VERSION: Premium Dashboard UI
//  - Beautiful Gradient Action Tiles
//  - Sleek Terminal/Console with Working Clear Button & Copy Button
//  - Instant Internet Restoration on Exit
//  - ROBUST VERSION: Auto-Sync, Debug Logging, Hidden Heartbeat, Selectable Console

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard functionality
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/client_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _WifiEntry {
  int slot;
  String ssid;
  String pass;
  _WifiEntry({required this.slot, required this.ssid, required this.pass});
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class AdminWifiSetupWidget extends StatefulWidget {
  final VoidCallback? onConfigComplete;
  const AdminWifiSetupWidget({super.key, this.onConfigComplete});

  @override
  State<AdminWifiSetupWidget> createState() => _AdminWifiSetupWidgetState();
}

class _AdminWifiSetupWidgetState extends State<AdminWifiSetupWidget> with WidgetsBindingObserver {

  // ── View State ─────────────────────────────────────────────────────────────
  // 0 = Scan, 1 = Admin Dashboard (Console), 2 = Hardware Config, 3 = WiFi Config
  int _viewState = 0;
  String? _originalDeviceId; // Ye sabse pehli (Old) ID ko sambhal kar rakhega

  // ── WiFi scan ──────────────────────────────────────────────────────────────
  List<WifiNetwork> _networks = [];
  String? _currentSSID;
  bool _isWifiEnabled = false;
  bool _isScanning = false;
  Map<String, String> _savedPasswords = {};
  Timer? _wifiMonitorTimer;

  // ── Socket ─────────────────────────────────────────────────────────────────
  Socket? _socket;
  final String _deviceIp = '192.168.4.1';
  final int _devicePort = 1336;
  Timer? _heartbeat;
  bool _isSocketConnected = false;

  // ── Async Completers for Save Flow ─────────────────────────────────────────
  Completer<void>? _wifiListOkCompleter;
  Completer<void>? _allDoneOkCompleter;

  // ── Device data fields ─────────────────────────────────────────────────────
  final _deviceIdCtrl = TextEditingController();
  final _newDeviceIdCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _hwVersionCtrl = TextEditingController();
  final _swVersionCtrl = TextEditingController();
  final _macCtrl = TextEditingController();
  bool _isFetchingDevice = false;
  bool _isSavingDevice = false;

  // ── WiFi config ────────────────────────────────────────────────────────────
  final List<_WifiEntry> _wifiList = [];
  bool _isFetchingWifi = false;
  bool _isSavingWifi = false;

  // ── Console ────────────────────────────────────────────────────────────────
  final List<String> _logs = [];
  final _logScrollCtrl = ScrollController();
  final _customCmdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("AdminWifiSetup: Initializing Screen & Observer");
    WidgetsBinding.instance.addObserver(this);
    _loadSavedPasswords();
    _initWifi();
  }

  @override
  void dispose() {
    print("AdminWifiSetup: Disposing resources...");
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _socket?.destroy();
    _wifiMonitorTimer?.cancel();
    _deviceIdCtrl.dispose();
    _newDeviceIdCtrl.dispose();
    _portCtrl.dispose();
    _hwVersionCtrl.dispose();
    _swVersionCtrl.dispose();
    _macCtrl.dispose();
    _logScrollCtrl.dispose();
    _customCmdCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("AdminWifiSetup: App Resumed - Re-initializing WiFi");
      _initWifi();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RESTORE INTERNET ON CLOSE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _closeAndRestoreInternet() async {
    _log('Closing and restoring internet...');
    print("AdminWifiSetup: Closing and restoring internet");
    _heartbeat?.cancel();
    _socket?.destroy();
    _socket = null;
    try {
      await WiFiForIoTPlugin.disconnect();
      await WiFiForIoTPlugin.forceWifiUsage(false);
    } catch (e) {
      print("AdminWifiSetup: Error disconnecting wifi -> $e");
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIFI SCAN
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadSavedPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      if (k.startsWith('wifi_pw_')) {
        _savedPasswords[k.replaceFirst('wifi_pw_', '')] = prefs.getString(k) ?? '';
      }
    }
  }

  Future<void> _initWifi() async {
    bool enabled = await WiFiForIoTPlugin.isEnabled();
    if (mounted) setState(() => _isWifiEnabled = enabled);
    if (enabled) {
      await _getCurrentSSID();
      await _scan();
      _startMonitor();
    }
  }

  Future<void> _getCurrentSSID() async {
    final ssid = await WiFiForIoTPlugin.getSSID();
    if (mounted) setState(() => _currentSSID = (ssid == '<unknown ssid>' ? null : ssid));
  }

  Future<void> _scan() async {
    if (!mounted) return;
    setState(() => _isScanning = true);
    print("AdminWifiSetup: Scanning for networks...");
    try {
      final r = await WiFiForIoTPlugin.loadWifiList();
      r.sort((a, b) {
        if (a.ssid == _currentSSID) return -1;
        if (b.ssid == _currentSSID) return 1;
        return (b.level ?? 0).compareTo(a.level ?? 0);
      });
      if (mounted) setState(() => _networks = r);
    } catch (e) {
      print("AdminWifiSetup: Scan failed -> $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _startMonitor() {
    _wifiMonitorTimer?.cancel();
    _wifiMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isWifiEnabled) return;
      final ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid != _currentSSID && mounted) _getCurrentSSID();
    });
  }

  void _handleNetworkTap(WifiNetwork net) {
    final ssid = net.ssid ?? 'Unknown';
    print("AdminWifiSetup: Tapped network $ssid");
    if (ssid == _currentSSID) {
      _onHotspotConnected();
      return;
    }
    final open = !(net.capabilities?.toUpperCase().contains('WPA') == true || net.capabilities?.toUpperCase().contains('WEP') == true);
    if (open) {
      _connect(ssid, '', sec: NetworkSecurity.NONE);
    } else if (_savedPasswords.containsKey(ssid)) {
      _connect(ssid, _savedPasswords[ssid]!, sec: NetworkSecurity.WPA);
    } else {
      _showPasswordDialog(ssid);
    }
  }

  Future<void> _connect(String ssid, String pass, {NetworkSecurity sec = NetworkSecurity.WPA}) async {
    print("AdminWifiSetup: Connecting to $ssid...");
    try {
      await WiFiForIoTPlugin.disconnect();
      final ok = await WiFiForIoTPlugin.connect(ssid, password: pass.isEmpty ? null : pass, security: sec, joinOnce: true);
      if (ok) {
        print("AdminWifiSetup: Connected successfully");
        if (pass.isNotEmpty) {
          final p = await SharedPreferences.getInstance();
          await p.setString('wifi_pw_$ssid', pass);
          _savedPasswords[ssid] = pass;
        }
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await Future.delayed(const Duration(seconds: 3));
        await _initWifi();
        _onHotspotConnected();
      } else {
        print("AdminWifiSetup: Connection returned false");
      }
    } catch (e) {
      print("AdminWifiSetup: Connection Exception -> $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connect failed: $e')));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SOCKET
  // ══════════════════════════════════════════════════════════════════════════

  void _onHotspotConnected() {
    print("AdminWifiSetup: Hotspot Connected. Moving to dashboard.");
    setState(() => _viewState = 1); // Jump to Dashboard
    _openSocket();
  }

  Future<void> _openSocket() async {
    if (_socket != null) return;
    _log('Connecting to $_deviceIp:$_devicePort...');
    print("AdminWifiSetup: Opening socket to $_deviceIp:$_devicePort");

    try {
      _socket = await Socket.connect(_deviceIp, _devicePort, timeout: const Duration(seconds: 5));
      if (mounted) setState(() => _isSocketConnected = true);
      _log('CONNECTED TO HARDWARE');
      _startHeartbeat();

      _socket!.listen(
            (Uint8List d) {
          final text = utf8.decode(d, allowMalformed: true).trim();
          print("AdminWifiSetup: RECV << $text");
          for (final line in text.split('\n')) {
            if (line.trim().isNotEmpty) {
              // Hide incoming KEEP_ALIVE echoes from the UI console
              if (!line.contains('KEEP_ALIVE')) {
                _log('← ${line.trim()}');
              }
              _handleResponse(line.trim());
            }
          }
        },
        onError: (e) {
          print("AdminWifiSetup: Socket Error -> $e");
          _onDisconnect();
        },
        onDone: () {
          print("AdminWifiSetup: Socket Done");
          _onDisconnect();
        },
      );

      // Run initial sequence
      await _runInitSequence();
    } catch (e) {
      _log('Connection failed: $e');
      print("AdminWifiSetup: Socket Connection Failed -> $e");
      if (mounted) setState(() => _isSocketConnected = false);
    }
  }

  void _onDisconnect() {
    print("AdminWifiSetup: Disconnected from hardware");
    _heartbeat?.cancel();
    _socket?.destroy();
    _socket = null;
    if (mounted) setState(() {
      _isSocketConnected = false;
      _isFetchingDevice = false;
      _isFetchingWifi = false;
    });
    _log('Disconnected');
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_socket != null && _isSocketConnected) _sendCmd('KEEP_ALIVE');
    });
  }

  Future<void> _sendCmd(String cmd) async {
    if (_socket == null) {
      _log('Error: Not connected');
      print("AdminWifiSetup: 🛑 SEND BLOCKED (Not Connected) >> $cmd");
      return;
    }

    // Hide outgoing KEEP_ALIVE from the UI console
    if (cmd != 'KEEP_ALIVE') {
      _log('→ $cmd');
    }

    print("AdminWifiSetup: 📤 SEND >> $cmd");
    try {
      _socket!.write('$cmd\r\n');
      await _socket!.flush(); // Robustness: Ensure flush
    } catch (e) {
      _log('Send error: $e');
      print("AdminWifiSetup: ❌ SEND ERROR -> $e");
      _onDisconnect();
    }
  }

  Future<void> _runInitSequence() async {
    print("AdminWifiSetup: Running Init Sequence");
    setState(() => _isFetchingDevice = true);
    final cmds = ['get_DEVICEID', 'get_PORT', 'get_HW_VERSION', 'get_VERSION', 'get_MACID', 'get_WIFILIST'];
    for (final c in cmds) {
      await _sendCmd(c);
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (mounted) setState(() => _isFetchingDevice = false);
  }

  void _handleResponse(String line) {
    // DEVICE ID
    if (line.contains('DEVICEID::')) {
      final v = line.split('::').last.trim();
      if (mounted) {
        setState(() {
          _deviceIdCtrl.text = v;
          _originalDeviceId ??= v; // Ye sirf First Time assign hoga, wahi Old ID banegi
        });
      }
      return;
    }

    // INTERCEPT TARGET ASYNC CONFIRMATIONS
    if (line.contains('WIFILIST::OK')) {
      print("AdminWifiSetup: 🎯 [RECV] Found WIFILIST::OK trigger");
      if (_wifiListOkCompleter != null && !_wifiListOkCompleter!.isCompleted) {
        _wifiListOkCompleter!.complete();
      }
      return;
    }

    if (line.contains('ALLDONE::OK')) {
      print("AdminWifiSetup: 🎯 [RECV] Found ALLDONE::OK trigger");
      if (_allDoneOkCompleter != null && !_allDoneOkCompleter!.isCompleted) {
        _allDoneOkCompleter!.complete();
      }
      return;
    }

    // WIFILIST PARSER (ROBUST)
    if (line.startsWith('WIFILIST::') || line.contains('ssid=')) {
      print("AdminWifiSetup: Parsing WIFILIST response...");

      // Remove header if present to avoid confusion
      final rawList = line.replaceAll('WIFILIST::', '');

      final regex = RegExp(r'ssid=(.*?);pass==?(.*?);');
      final matches = regex.allMatches(rawList);

      final List<_WifiEntry> parsedList = [];
      int slotCounter = 1;

      for (final match in matches) {
        if (slotCounter > 5) break;
        String ssid = match.group(1) ?? '';
        String pass = match.group(2) ?? '';

        // Filter out empty or default placeholders
        if (ssid.isNotEmpty && ssid != 'NODEF') {
          parsedList.add(_WifiEntry(slot: slotCounter, ssid: ssid, pass: pass));
          slotCounter++;
        }
      }

      if (mounted) {
        setState(() {
          _wifiList.clear();
          _wifiList.addAll(parsedList);
          // Auto-stop loading if this was a refresh
          _isFetchingWifi = false;
        });
      }
      return;
    }

    // Single WiFi Update (Echo)
    final wm = RegExp(r'WIFI(\d)::ssid=([^;]*);pass==([^;]*);?').firstMatch(line);
    if (wm != null) {
      final slot = int.parse(wm.group(1)!);
      final ssid = wm.group(2)!;
      final pass = wm.group(3)!;
      if (mounted) setState(() {
        _wifiList.removeWhere((w) => w.slot == slot);
        if (ssid.isNotEmpty && ssid != 'NODEF') {
          _wifiList.add(_WifiEntry(slot: slot, ssid: ssid, pass: pass));
        }
        _wifiList.sort((a, b) => a.slot.compareTo(b.slot));
      });
      return;
    }

    if (line.contains('PORT::')) {
      final v = line.split('::').last.trim();
      if (mounted) setState(() => _portCtrl.text = v);
      return;
    }
    if (line.contains('HW_VERSION::')) {
      final v = line.split('::').last.trim();
      if (mounted) setState(() => _hwVersionCtrl.text = v);
      return;
    }
    if (line.startsWith('VERSION::') || line.startsWith('VER::')) {
      final v = line.split('::').last.trim();
      if (mounted) setState(() => _swVersionCtrl.text = v);
      return;
    }
    if (line.contains('MACID::')) {
      final v = line.split('::').last.trim();
      if (mounted) setState(() => _macCtrl.text = v);
      return;
    }
    if (line.toUpperCase().contains('RESETMEM')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memory Reset Successful!'), backgroundColor: Colors.green));
    }
  }

  void _log(String msg) {
    if (!mounted) return;
    final time = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() => _logs.add('[$time] $msg'));
    // Auto-scroll
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(_logScrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DEVICE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _setDeviceId() async {
    final newId = _newDeviceIdCtrl.text.trim();
    if (newId.isNotEmpty) await _sendCmd('set_DEVICEID::$newId;');
  }
  Future<void> _setPort() async {
    final port = _portCtrl.text.trim();
    if (port.isNotEmpty) await _sendCmd('set_PORT::$port;');
  }
  Future<void> _setHwVersion() async {
    final v = _hwVersionCtrl.text.trim();
    if (v.isNotEmpty) await _sendCmd('set_HW_VERSION::$v;');
  }

  Future<void> _saveToDatabase() async {
    print("=========================================");
    print("AdminWifiSetup: 1. STARTING SAVE SEQUENCE");
    print("=========================================");

    // YAHAN LOGIC CHANGE HUA HAI:
    // Old ID: Jo sabse pehle hardware se aayi thi (background saved)
    final oldIdRaw = _originalDeviceId ?? _deviceIdCtrl.text.trim();

    // New ID: Jo user ne box me type karke send kari hai
    final newIdRaw = _newDeviceIdCtrl.text.trim();

    final hwVersion = _hwVersionCtrl.text.trim();
    final swVersion = _swVersionCtrl.text.trim();
    final macId = _macCtrl.text.trim();

    if (oldIdRaw.isEmpty) {
      print("AdminWifiSetup: ERROR - Current Device ID is empty. Hardware didn't send it.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please GET Current Device ID first.')));
      return;
    }

    // Convert to integers
    final oldRecNo = int.tryParse(oldIdRaw) ?? 0;

    // Agar New ID box khali hai, iska matlab usne SET nahi kiya, to Old ID hi New ID ban jayegi
    final newRecNo = newIdRaw.isNotEmpty ? (int.tryParse(newIdRaw) ?? oldRecNo) : oldRecNo;

    if (oldRecNo == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Current Device ID format.')));
      return;
    }

    final clientProvider = Provider.of<ClientProvider>(context, listen: false);

    setState(() => _isSavingDevice = true);

    try {
      print("AdminWifiSetup: 2. Disconnecting socket and Wi-Fi hotspot...");
      _socket?.destroy();
      _socket = null;
      await WiFiForIoTPlugin.disconnect();
      await WiFiForIoTPlugin.forceWifiUsage(false);

      print("AdminWifiSetup: 3. Waiting 6 seconds for OS to restore internet...");
      await Future.delayed(const Duration(seconds: 6));

      print("AdminWifiSetup: 4. Checking if internet is restored...");
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection restored yet.');
      }
      print("AdminWifiSetup: Internet check passed.");

      final requestBody = {
        'action': 'UPDATE_DEVICE_FULL',
        'OldRecNo': oldRecNo,
        'NewRecNo': newRecNo,
        'HwVersion': hwVersion,
        'SwVersion': swVersion,
        'MacId': macId
      };

      print("AdminWifiSetup: 5. HITTING API ENDPOINT => ${ApiConstants.baseUrl}/device_id_update_api.php");
      print("AdminWifiSetup: REQUEST BODY => ${jsonEncode(requestBody)}");

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/device_id_update_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print("AdminWifiSetup: 6. API CALL FINISHED");
      print("AdminWifiSetup: RESPONSE STATUS CODE => ${response.statusCode}");
      print("AdminWifiSetup: RAW RESPONSE BODY => ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          print("AdminWifiSetup: 7. Success! Updating provider with NewRecNo: $newRecNo...");

          await clientProvider.updateAfterHardwareSync(newRecNo);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Database successfully!'), backgroundColor: Colors.green));
            widget.onConfigComplete?.call();
          }
        } else {
          print("AdminWifiSetup: API Returned Error Status => ${data['message']}");
          throw Exception(data['message'] ?? 'Database update failed');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print("AdminWifiSetup: CAUGHT EXCEPTION => $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      print("AdminWifiSetup: 8. SEQUENCE COMPLETE. Resetting UI state.");
      print("=========================================");
      if (mounted) setState(() {
        _isSavingDevice = false;
        _viewState = 0;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIFI ACTIONS (BATCH & FIX)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _refreshWifiList() async {
    print("AdminWifiSetup: Refreshing WiFi List");
    setState(() {
      _isFetchingWifi = true;
      _wifiList.clear();
    });
    await _sendCmd('get_WIFILIST');
    // Timeout backup in case hardware doesn't reply
    await Future.delayed(const Duration(seconds: 4));
    if (mounted && _isFetchingWifi) {
      setState(() => _isFetchingWifi = false);
    }
  }

  void _reassignSlots() {
    for (int i = 0; i < _wifiList.length; i++) {
      _wifiList[i].slot = i + 1;
    }
  }

  void _showAddWifiDialog() {
    if (_wifiList.length < 5) _showWifiInputSheet(title: 'Add Wi-Fi', isAdd: true);
  }

  void _showEditWifiDialog(_WifiEntry w) {
    _showWifiInputSheet(title: 'Edit Wi-Fi', isAdd: false, target: w, initSsid: w.ssid, initPass: w.pass);
  }

  void _showWifiInputSheet({required String title, required bool isAdd, _WifiEntry? target, String? initSsid, String? initPass}) {
    final ssidCtrl = TextEditingController(text: initSsid);
    final passCtrl = TextEditingController(text: initPass);
    bool obscure = true;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ssidCtrl, decoration: InputDecoration(labelText: 'SSID', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: passCtrl, obscureText: obscure, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setS(() => obscure = !obscure)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            final s = ssidCtrl.text.trim();
            final p = passCtrl.text.trim();
            if (s.isEmpty) return;
            setState(() {
              if (isAdd) {
                _wifiList.add(_WifiEntry(slot: 0, ssid: s, pass: p));
              } else if (target != null) {
                target.ssid = s;
                target.pass = p;
              }
              _reassignSlots();
            });
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Save Locally'),
        ),
      ],
    )));
  }

  void _removeWifi(_WifiEntry w) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Remove Wi-Fi?'),
      content: Text('Remove "${w.ssid}" from local list?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
            onPressed: () {
              setState(() {
                _wifiList.remove(w);
                _reassignSlots();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Remove')),
      ],
    ));
  }

  // AUTO-SYNC LOGIC
  Future<void> _syncWifiToDevice() async {
    print("=========================================");
    print("AdminWifiSetup: 🚀 Starting Batch Sync...");
    print("=========================================");
    setState(() => _isSavingWifi = true);

    try {
      _wifiListOkCompleter = Completer<void>();

      // 1. Send all slots sequentially with delays
      for (int i = 1; i <= 5; i++) {
        String cmd;
        int index = i - 1;
        if (index < _wifiList.length) {
          final w = _wifiList[index];
          // Fixed pass== to pass=
          cmd = 'set_WIFI$i::ssid=${w.ssid};pass=${w.pass};';
        } else {
          // Fixed pass== to pass=
          cmd = 'set_WIFI$i::ssid=NODEF;pass=NODEF;';
        }
        print("AdminWifiSetup: 📤 [Cmd $i/5] -> $cmd");
        await _sendCmd(cmd);
        // Delay to allow hardware EEPROM write
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _log('Sync commands sent. Waiting for WIFILIST::OK...');
      print("AdminWifiSetup: ⏳ Waiting for WIFILIST::OK...");

      await _wifiListOkCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout waiting for WIFILIST::OK response'),
      );

      print("AdminWifiSetup: ✅ Device confirmed WIFILIST::OK");
      _log('Verified: WIFILIST::OK');

      // 2. Send ALLDONE command and wait
      _allDoneOkCompleter = Completer<void>();
      print("AdminWifiSetup: 📤 Sending -> set_ALLDONE");
      await _sendCmd('set_ALLDONE');

      print("AdminWifiSetup: ⏳ Waiting for ALLDONE::OK...");
      await _allDoneOkCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout waiting for ALLDONE::OK response'),
      );

      print("AdminWifiSetup: ✅ Device confirmed ALLDONE::OK");
      _log('Verified: ALLDONE::OK');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WiFi Synced Successfully! Disconnecting...'), backgroundColor: Colors.green));
      }

      print("AdminWifiSetup: 🔌 Disconnecting and closing Admin setup...");
      await Future.delayed(const Duration(milliseconds: 800)); // Small pause before exit
      await _closeAndRestoreInternet();

    } catch(e) {
      print("AdminWifiSetup: ❌ Sync Error -> $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync Error: $e'), backgroundColor: Colors.red));
      if (mounted) setState(() => _isSavingWifi = false);
    } finally {
      // Clean up completers
      _wifiListOkCompleter = null;
      _allDoneOkCompleter = null;
    }
  }

  void _confirmReset() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Icon(Iconsax.warning_2, color: Colors.orange.shade600), const SizedBox(width: 8), const Text('Reset Memory?')]),
      content: const Text('This erases all data on the device and cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendCmd('set_RESETMEM;');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Reset')),
      ],
    ));
  }

  void _showPasswordDialog(String ssid) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [const Icon(Icons.lock, size: 18), const SizedBox(width: 8), Text('Connect to $ssid', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
      content: TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: InputDecoration(hintText: 'Enter Password', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _connect(ssid, ctrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Connect')),
      ],
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // PopScope intercepts the hardware back button to clean up
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_viewState > 1) {
          setState(() => _viewState = 1);
          return;
        } // Go back to Dashboard
        await _closeAndRestoreInternet(); // Actually close widget
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_viewState) {
      case 0: return _buildScanPhase();
      case 1: return _buildDashboard();
      case 2: return _buildHardwareScreen();
      case 3: return _buildWifiScreen();
      default: return _buildScanPhase();
    }
  }

  // ── 0. Scan Phase ──────────────────────────────────────────────────────────
  Widget _buildScanPhase() {
    return Column(children: [
      _buildTopBar('Connect to Device', isDashboard: false),
      if (!_isWifiEnabled)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Iconsax.wifi_square, size: 60, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Wi-Fi is Disabled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: () => WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true), icon: const Icon(Iconsax.flash_1), label: const Text('Enable Wi-Fi'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
        ])))
      else
        Expanded(child: _buildScanList()),
    ]);
  }

  Widget _buildScanList() {
    if (_networks.isEmpty && !_isScanning) return const Center(child: Text('No networks found'));
    return RefreshIndicator(
      onRefresh: _scan,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _networks.length,
        itemBuilder: (ctx, i) {
          final net = _networks[i];
          final isCur = net.ssid == _currentSSID && _currentSSID != null;
          final isSaved = _savedPasswords.containsKey(net.ssid);
          final isOpen = !(net.capabilities?.toUpperCase().contains('WPA') == true);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: isCur ? AppTheme.primaryBlue.withOpacity(0.06) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isCur ? AppTheme.primaryBlue : Colors.grey.shade200, width: isCur ? 1.5 : 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: isCur ? AppTheme.primaryBlue : Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Iconsax.wifi, color: isCur ? Colors.white : Colors.grey, size: 19)),
              title: Text(net.ssid ?? 'Hidden', style: TextStyle(fontWeight: FontWeight.w600, color: isCur ? AppTheme.primaryBlue : Colors.black87)),
              subtitle: Wrap(spacing: 6, children: [
                if (isCur) _pill('Connected', Colors.green),
                if (isSaved && !isCur) _pill('Saved', Colors.blue),
                if (isOpen) _pill('Open', Colors.orange),
              ]),
              trailing: isCur ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
              onTap: () => _handleNetworkTap(net),
            ),
          );
        },
      ),
    );
  }

  // ── 1. Admin Dashboard ─────────────────────────────────────────────────────
  Widget _buildDashboard() {
    return Column(children: [
      _buildTopBar('Admin Dashboard', isDashboard: true),

      // Beautiful Gradient Action Tiles Row
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(child: _buildGradientTile('Hardware Setup', 'IDs & Ports', Iconsax.cpu, [Colors.blue.shade700, Colors.blue.shade400], () => setState(() => _viewState = 2))),
          const SizedBox(width: 12),
          Expanded(child: _buildGradientTile('Wi-Fi Setup', 'Manage Channels', Iconsax.wifi, [Colors.orange.shade700, Colors.orange.shade400], () => setState(() => _viewState = 3))),
        ]),
      ),

      // Reset Button
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: _confirmReset,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.shade100)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Iconsax.warning_2, color: Colors.red.shade600, size: 18),
              const SizedBox(width: 8),
              Text('Reset Device Memory', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        ),
      ),

      const SizedBox(height: 12),

      // Console Area (Takes remaining space)
      Expanded(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
          ),
          child: Column(children: [
            // Console Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
              ),
              child: Row(children: [
                const Icon(Iconsax.code, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Text('Live Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (_isSocketConnected)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('LIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))
                  ),
                const SizedBox(width: 8),

                // NEW: Copy All Logs Button
                IconButton(
                  onPressed: () {
                    if (_logs.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: _logs.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Console logs copied!'), backgroundColor: Colors.green));
                    }
                  },
                  icon: const Icon(Iconsax.copy, color: Colors.blueAccent, size: 20),
                  tooltip: 'Copy Logs',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),

                // Clear Console Button
                IconButton(
                  onPressed: () { setState(() { _logs.clear(); }); },
                  icon: const Icon(Iconsax.trash, color: Colors.redAccent, size: 20),
                  tooltip: 'Clear Console',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
              ]),
            ),

            // Console Logs
            Expanded(
              child: _logs.isEmpty
                  ? Center(child: Text('No logs yet. Waiting for data...', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontFamily: 'monospace')))
                  : ListView.builder(
                controller: _logScrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (ctx, i) {
                  final log = _logs[i];
                  Color c = Colors.greenAccent;
                  if (log.contains('→')) c = Colors.cyanAccent;
                  if (log.contains('Error') || log.contains('Failed')) c = Colors.redAccent;
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      // NEW: Replaced Text with SelectableText to allow copying specific lines
                      child: SelectableText(log, style: TextStyle(color: c, fontSize: 11.5, fontFamily: 'monospace', height: 1.3))
                  );
                },
              ),
            ),

            // Custom Command Input Area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
              ),
              child: Row(children: [
                const Text('>', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _customCmdCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter command...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (c) async { if (c.trim().isNotEmpty) { await _sendCmd(c.trim()); _customCmdCtrl.clear(); } },
                )),
                IconButton(
                  onPressed: () async { final c = _customCmdCtrl.text.trim(); if (c.isNotEmpty) { await _sendCmd(c); _customCmdCtrl.clear(); } },
                  icon: const Icon(Iconsax.send_1, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
    ]);
  }

  // ── 2. Hardware Screen ─────────────────────────────────────────────────────
  Widget _buildHardwareScreen() {
    return Column(children: [
      _buildTopBar('Hardware Config', showBack: true),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_isFetchingDevice) const LinearProgressIndicator(),
            const SizedBox(height: 8),

            _sectionHeader('Device ID', Iconsax.mobile),
            _card(child: Column(children: [
              _readonlyField('Current ID', _deviceIdCtrl, Iconsax.cpu),
              const SizedBox(height: 12),
              _editableField('New Device ID', _newDeviceIdCtrl, Iconsax.edit, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(children: [ Expanded(child: _actionBtn('GET', Iconsax.refresh, () => _sendCmd('get_DEVICEID'), color: Colors.blueGrey)), const SizedBox(width: 8), Expanded(child: _actionBtn('SET', Iconsax.send_1, _setDeviceId, color: AppTheme.primaryBlue)), ]),
            ])),
            const SizedBox(height: 16),

            _sectionHeader('Network Port', Iconsax.global),
            _card(child: Column(children: [
              _editableField('Port Number', _portCtrl, Iconsax.global, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(children: [ Expanded(child: _actionBtn('GET', Iconsax.refresh, () => _sendCmd('get_PORT'), color: Colors.blueGrey)), const SizedBox(width: 8), Expanded(child: _actionBtn('SET', Iconsax.send_1, _setPort, color: AppTheme.primaryBlue)), ]),
            ])),
            const SizedBox(height: 16),

            _sectionHeader('Hardware Version', Iconsax.cpu),
            _card(child: Column(children: [
              _editableField('HW Version', _hwVersionCtrl, Iconsax.element_4),
              const SizedBox(height: 12),
              Row(children: [ Expanded(child: _actionBtn('GET', Iconsax.refresh, () => _sendCmd('get_HW_VERSION'), color: Colors.blueGrey)), const SizedBox(width: 8), Expanded(child: _actionBtn('SET', Iconsax.send_1, _setHwVersion, color: AppTheme.primaryBlue)), ]),
            ])),
            const SizedBox(height: 16),

            _sectionHeader('System Info', Iconsax.info_circle),
            _card(child: Column(children: [
              _readonlyField('Software Version', _swVersionCtrl, Iconsax.code),
              const SizedBox(height: 12),
              _readonlyField('MAC Address', _macCtrl, Iconsax.routing),
              const SizedBox(height: 12),
              Row(children: [ Expanded(child: _actionBtn('GET VER', Iconsax.refresh, () => _sendCmd('get_VERSION'), color: Colors.blueGrey)), const SizedBox(width: 8), Expanded(child: _actionBtn('GET MAC', Iconsax.refresh, () => _sendCmd('get_MACID'), color: Colors.blueGrey)), ]),
            ])),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSavingDevice ? null : _saveToDatabase,
                icon: _isSavingDevice ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Iconsax.cloud_plus, color: Colors.white),
                label: Text(_isSavingDevice ? 'SAVING TO DB...' : 'SAVE TO DATABASE & EXIT', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    ]);
  }

  // ── 3. Wi-Fi Screen ────────────────────────────────────────────────────────
  Widget _buildWifiScreen() {
    final canAdd = _wifiList.length < 5;
    return Column(children: [
      _buildTopBar('Wi-Fi Setup', showBack: true),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(children: [
          Text('Saved Networks (${_wifiList.length}/5)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const Spacer(),
          if (_isFetchingWifi || _isSavingWifi) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(icon: const Icon(Iconsax.refresh, size: 22), color: AppTheme.primaryBlue, onPressed: _refreshWifiList, tooltip: 'Refresh list'),
        ]),
      ),
      Expanded(
        child: _isFetchingWifi
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          ..._wifiList.map((w) => _buildWifiEntryTile(w)),
          const SizedBox(height: 8),
          Opacity(opacity: canAdd ? 1.0 : 0.4,
            child: InkWell(
              onTap: canAdd ? _showAddWifiDialog : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: canAdd ? AppTheme.primaryBlue.withOpacity(0.4) : Colors.grey.shade300, style: BorderStyle.solid), borderRadius: BorderRadius.circular(14), color: canAdd ? AppTheme.primaryBlue.withOpacity(0.03) : Colors.grey.shade50),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Iconsax.add, color: canAdd ? AppTheme.primaryBlue : Colors.grey),
                  const SizedBox(width: 8),
                  Text(canAdd ? 'Add Wi-Fi Network' : 'Maximum 5 Networks Reached', style: TextStyle(color: canAdd ? AppTheme.primaryBlue : Colors.grey, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            onPressed: _isSavingWifi ? null : _syncWifiToDevice,
            icon: _isSavingWifi ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Iconsax.export_1, color: Colors.white),
            label: Text(_isSavingWifi ? 'SYNCING...' : 'SYNC ALL WIFI TO DEVICE', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ),
    ]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  WIFI ENTRY TILE
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildWifiEntryTile(_WifiEntry w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]
      ),
      child: ListTile(
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(Iconsax.wifi, color: AppTheme.primaryBlue, size: 20)
        ),
        title: Text(w.ssid, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Slot ${w.slot} · ${w.pass.isEmpty ? 'Open' : 'Encrypted'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Iconsax.edit, color: Colors.blue.shade400, size: 20), onPressed: () => _showEditWifiDialog(w)),
            IconButton(icon: Icon(Iconsax.trash, color: Colors.red.shade400, size: 20), onPressed: () => _removeWifi(w)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar(String title, {bool showBack = false, bool isDashboard = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
      child: Row(children: [
        if (showBack) IconButton(icon: const Icon(Iconsax.arrow_left_2), onPressed: () => setState(() => _viewState = 1)),
        if (!showBack) const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (!showBack) Row(children: [
            Icon(Icons.circle, size: 8, color: _isSocketConnected ? Colors.green : (_viewState == 0 ? Colors.grey : Colors.orange)),
            const SizedBox(width: 6),
            Text(_isSocketConnected ? 'Socket Connected' : (_viewState == 0 ? 'Scan nearby hotspots' : 'Connecting...'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ])),
        if (_viewState == 0) IconButton(onPressed: _scan, icon: _isScanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue)) : const Icon(Iconsax.refresh, color: AppTheme.primaryBlue)),
        // The Red X button instantly calls the internet restore function
        IconButton(icon: const Icon(Iconsax.close_circle, color: Colors.red, size: 28), onPressed: _closeAndRestoreInternet),
      ]),
    );
  }

  Widget _buildGradientTile(String title, String subtitle, IconData icon, List<Color> colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 28)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [ Icon(icon, size: 16, color: AppTheme.primaryBlue), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)), ]),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
    child: child,
  );

  Widget _readonlyField(String label, TextEditingController ctrl, IconData icon) => TextField(
    controller: ctrl, readOnly: true, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
  );

  Widget _editableField(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) => TextField(
    controller: ctrl, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
  );

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap, {required Color color}) {
    return ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 16, color: Colors.white), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)));
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}