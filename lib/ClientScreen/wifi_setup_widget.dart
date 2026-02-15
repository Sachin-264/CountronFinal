// [UPDATE] lib/ClientScreen/wifi_setup_widget.dart

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
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/client_provider.dart';
import '../../theme/client_theme.dart';
import '../widgets/constants.dart';

class WifiSetupWidget extends StatefulWidget {
  final VoidCallback onConnected;
  const WifiSetupWidget({super.key, required this.onConnected});

  @override
  State<WifiSetupWidget> createState() => _WifiSetupWidgetState();
}

class _WifiSetupWidgetState extends State<WifiSetupWidget> with WidgetsBindingObserver {
  // --- Wi-Fi State ---
  List<WifiNetwork> _networks = [];
  String? _currentSSID;
  bool _isEnabled = false;
  bool _isScanning = false;
  bool _isCheckingInternet = false;
  Map<String, String> _savedPasswords = {};
  Timer? _wifiMonitorTimer;

  // --- Socket / Config State ---
  bool _isConfiguring = false;
  Socket? _socket;
  final String _deviceIp = '192.168.4.1';
  final int _devicePort = 1336;

  // Robustness Timers
  Timer? _keepAliveTimer;
  bool _isSocketConnected = false;

  // --- UI Controllers ---
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _getCmdController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedCredentials();
    _initializeWifi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSocketHeartbeat();
    _disconnectSocket();
    _wifiMonitorTimer?.cancel();
    _deviceIdController.dispose();
    _getCmdController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeWifi();
    }
  }

  // ==========================================
  //            WI-FI LOGIC
  // ==========================================

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('wifi_pw_')) {
        _savedPasswords[key.replaceFirst('wifi_pw_', '')] = prefs.getString(key) ?? '';
      }
    }
  }

  Future<void> _initializeWifi() async {
    await _checkWifiStatus();
    if (_isEnabled) {
      await _getCurrentConnectedWifi();
      await _scanWifi();
      _startWifiMonitoring();
    }
  }

  Future<void> _checkWifiStatus() async {
    bool isEnabled = await WiFiForIoTPlugin.isEnabled();
    if (mounted) setState(() => _isEnabled = isEnabled);
  }

  Future<void> _getCurrentConnectedWifi() async {
    String? ssid = await WiFiForIoTPlugin.getSSID();
    if (mounted) setState(() => _currentSSID = (ssid == '<unknown ssid>' ? null : ssid));
  }

  Future<void> _scanWifi() async {
    if (!mounted) return;
    setState(() => _isScanning = true);
    try {
      List<WifiNetwork> htResult = await WiFiForIoTPlugin.loadWifiList();
      htResult.sort((a, b) {
        if (a.ssid == _currentSSID) return -1;
        if (b.ssid == _currentSSID) return 1;
        return (b.level ?? 0).compareTo(a.level ?? 0);
      });

      if (mounted) setState(() => _networks = htResult);
    } catch (e) {
      debugPrint("SCAN ERROR: $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _handleNetworkTap(WifiNetwork network) {
    final String ssid = network.ssid ?? "Unknown";

    if (ssid == _currentSSID) {
      _startConfigurationMode();
      return;
    }

    bool isOpen = network.capabilities?.toUpperCase().contains("WPA") == false &&
        network.capabilities?.toUpperCase().contains("WEP") == false;

    if (isOpen) {
      _connectToWifi(ssid, "", security: NetworkSecurity.NONE);
    } else if (_savedPasswords.containsKey(ssid)) {
      _connectToWifi(ssid, _savedPasswords[ssid]!, security: NetworkSecurity.WPA);
    } else {
      _showPasswordDialog(ssid);
    }
  }

  Future<void> _connectToWifi(String ssid, String password, {NetworkSecurity security = NetworkSecurity.WPA}) async {
    try {
      await WiFiForIoTPlugin.disconnect();
      bool result = await WiFiForIoTPlugin.connect(
        ssid,
        password: password.isEmpty ? null : password,
        security: security,
        joinOnce: true,
      );

      if (result) {
        if (password.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('wifi_pw_$ssid', password);
          _savedPasswords[ssid] = password;
        }
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await Future.delayed(const Duration(seconds: 3));
        await _initializeWifi();
        _startConfigurationMode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Failed: $e")));
      }
    }
  }

  void _startWifiMonitoring() {
    _wifiMonitorTimer?.cancel();
    _wifiMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isEnabled) return;
      String? ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid != _currentSSID && mounted) {
        _getCurrentConnectedWifi();
      }
    });
  }

  // ==========================================
  //        ROBUST SOCKET LOGIC (UPDATED)
  // ==========================================

  void _startConfigurationMode() {
    setState(() {
      _isConfiguring = true;
      _logs.clear();
      _addLog("Entering Configuration Mode...");
    });
    // Start the connection loop
    _initSocketConnection();
  }

  Future<void> _initSocketConnection() async {
    // If already connected, don't reconnect
    if (_socket != null) return;

    _addLog("Attempting to connect to $_deviceIp:$_devicePort...");
    print("DEBUG: Connecting to $_deviceIp:$_devicePort");

    try {
      _socket = await Socket.connect(_deviceIp, _devicePort, timeout: const Duration(seconds: 5));

      setState(() => _isSocketConnected = true);
      _addLog("CONNECTED");
      print("DEBUG: Socket Connected");

      // Send initial Keep Alive immediately
      _sendCommand("KEEP_ALIVE");
      _startSocketHeartbeat();

      // Listen for data
      _socket!.listen(
            (Uint8List data) {
          // Use allowMalformed to handle garbage characters without crashing
          final response = utf8.decode(data, allowMalformed: true).trim();
          print("DEBUG: Received: $response");

          // Log it properly
          if (response.isNotEmpty) {
            // Handle multiple lines if they come in one packet
            final lines = response.split('\n');
            for (var line in lines) {
              if (line.trim().isNotEmpty) {
                _addLog("Received: \"${line.trim()}\"");
                _handleSocketResponse(line.trim());
              }
            }
          }
        },
        onError: (error) {
          _addLog("Socket Error: $error");
          print("DEBUG: Socket Error: $error");
          _handleDisconnection();
        },
        onDone: () {
          _addLog("Socket Closed by Server");
          print("DEBUG: Socket Closed by Server");
          _handleDisconnection();
        },
      );

      // Run the full command sequence
      await _runAutoCommands();

    } catch (e) {
      _addLog("Connection Failed: $e");
      print("DEBUG: Connection Failed: $e");
      setState(() => _isSocketConnected = false);
      // Retry logic could go here if desired
    }
  }

  void _handleDisconnection() {
    setState(() => _isSocketConnected = false);
    _stopSocketHeartbeat();
    _socket?.destroy();
    _socket = null;
    _addLog("Disconnected. Tap Refresh to retry.");
  }

  void _startSocketHeartbeat() {
    _stopSocketHeartbeat();
    // Send KEEP_ALIVE every 10 seconds to keep connection robust
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_socket != null && _isSocketConnected) {
        _sendCommand("KEEP_ALIVE");
      }
    });
  }

  void _stopSocketHeartbeat() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _disconnectSocket() {
    _stopSocketHeartbeat();
    _socket?.destroy();
    _socket = null;
    setState(() => _isSocketConnected = false);
  }

  // Parses response for UI updates (like Device ID)
  void _handleSocketResponse(String response) {
    if (response.contains("DEVICEID::")) {
      final parts = response.split("::");
      if (parts.length > 1) {
        final id = parts[1].trim();
        setState(() {
          _deviceIdController.text = id;
        });
        print("DEBUG: Parsed Device ID: $id");
      }
    }
  }

  Future<void> _sendCommand(String cmd) async {
    if (_socket == null) {
      _addLog("Error: Not connected");
      return;
    }
    try {
      _addLog("Message Send: $cmd");
      print("DEBUG: Message Send: $cmd");
      _socket!.write("$cmd\r\n"); // \r\n is standard for many IoT devices
    } catch (e) {
      _addLog("Send Error: $e");
      print("DEBUG: Send Error: $e");
      _handleDisconnection();
    }
  }

  // Matches the exact log sequence provided by user
  Future<void> _runAutoCommands() async {
    final cmds = [
      "get_SENSORID",
      "get_JSON_SERVER_IP",
      "get_STARTUP_IP",
      "get_IS_JSON",
      "get_DEVICEID",
      "set_DATETIME::${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}",
      "get_IS_ETH",
      "get_ETHERNET_MACID",
      "get_WIFILIST",
      "get_VERSION",
      "get_OPC_SENSORID",
      "get_IS_HTTPS",
      "get_IS_WIFI_ALWAYS_ON",
      "get_TEMPERATURE",
      "get_DATACHECK",
      "get_DEVICE_TYPE",
      "get_HUMIDITY",
      "get_INTERVAL",
      "get_AQITYPE",
      "get_LUX",
      "get_BAND_L",
      "get_BAND_H",
      "get_SENSID_NO2",
      "get_SENSID_O3",
      "get_SENSID_SO2",
      "get_SENSID_CO",
      "get_NOISE",
      "get_PORT",
    ];

    print("DEBUG: Starting Auto Command Sequence (${cmds.length} commands)");

    for (var cmd in cmds) {
      if (_socket == null) {
        print("DEBUG: Sequence aborted - Socket null");
        break;
      }

      await _sendCommand(cmd);
      // Wait a bit between commands so we don't flood the microcontroller
      await Future.delayed(const Duration(milliseconds: 350));
    }
    _addLog("Auto Sequence Complete.");
    print("DEBUG: Auto Sequence Complete.");
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add("[${DateFormat('HH:mm:ss').format(DateTime.now())}] $msg");
    });
    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================
  //        API / SAVE LOGIC
  // ==========================================

  Future<void> _handleSaveAndNext() async {
    debugPrint("=== SAVE BUTTON CLICKED ===");
    _addLog("Initiating Save Sequence...");

    final String newDeviceIdStr = _deviceIdController.text.trim();
    if (newDeviceIdStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No Device ID received from hardware.")),
      );
      return;
    }

    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final int oldRecNo = clientProvider.selectedDeviceRecNo ?? 0;

    if (oldRecNo == 0) {
      _addLog("Error: Invalid Old Device ID (0).");
      return;
    }

    setState(() => _isCheckingInternet = true);

    // Disconnect Hardware to restore Internet
    _addLog("Restoring Internet connection...");
    try {
      _disconnectSocket();
      await WiFiForIoTPlugin.disconnect();
      await WiFiForIoTPlugin.forceWifiUsage(false);
    } catch (e) {
      debugPrint("Disconnect Warning: $e");
    }

    _addLog("Waiting for network switch (6s)...");
    await Future.delayed(const Duration(seconds: 6));

    try {
      _addLog("Verifying Internet Access...");
      final result = await InternetAddress.lookup('google.com');

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _addLog("Internet Active. Syncing to Database...");

        final String apiUrl = "${ApiConstants.baseUrl}/device_id_update_api.php";
        print("DEBUG: Calling API: $apiUrl");

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "action": "UPDATE_DEVICE_ID",
            "OldRecNo": oldRecNo,
            "NewRecNo": int.parse(newDeviceIdStr),
          }),
        );

        debugPrint("API Response: ${response.statusCode} | Body: ${response.body}");

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success') {
            _addLog("ID Synchronized Successfully!");

            final int newId = int.parse(newDeviceIdStr);
            await clientProvider.updateAfterHardwareSync(newId);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Device Configured Successfully!"),
                  backgroundColor: ClientTheme.success,
                  duration: Duration(seconds: 2),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 1500));
              widget.onConnected();
            }
          } else {
            throw Exception(responseData['message'] ?? "Update Failed");
          }
        } else {
          throw Exception("HTTP Error ${response.statusCode}");
        }
      } else {
        throw Exception("No Internet Connection detected.");
      }
    } catch (e) {
      debugPrint("SAVE ERROR: $e");
      _addLog("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${e.toString().replaceAll('Exception:', '')}"),
            backgroundColor: ClientTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingInternet = false);
    }
  }

  // ==========================================
  //        UI BUILDERS
  // ==========================================

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
          else if (_isConfiguring)
            Expanded(child: _buildConfigurationPanel())
          else
            Expanded(child: _buildNetworkList()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEnabled
                      ? (_isConfiguring ? "Device Config" : "Wi-Fi Networks")
                      : "Setup Required",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClientTheme.textDark),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: _isSocketConnected ? ClientTheme.success : (_isEnabled ? Colors.orange : ClientTheme.error)),
                    const SizedBox(width: 6),
                    Text(
                      _isEnabled
                          ? (_isConfiguring
                          ? (_isSocketConnected ? "Connected" : "Disconnected")
                          : "Scanning Nearby...")
                          : "Wi-Fi is Off",
                      style: TextStyle(color: ClientTheme.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (_isEnabled && !_isConfiguring)
                IconButton(
                  onPressed: _scanWifi,
                  icon: _isScanning
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ClientTheme.primaryColor))
                      : Icon(Iconsax.refresh, color: ClientTheme.primaryColor),
                ),
              if (_isConfiguring && !_isSocketConnected)
                IconButton(
                  onPressed: _initSocketConnection,
                  tooltip: "Reconnect",
                  icon: const Icon(Iconsax.refresh, color: Colors.orange),
                ),
              IconButton(
                icon: const Icon(Iconsax.close_circle, color: ClientTheme.error),
                tooltip: "Close Setup",
                onPressed: () {
                  _disconnectSocket();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWifiOffState() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: ClientTheme.error.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(Iconsax.wifi_square, size: 40, color: ClientTheme.error.withOpacity(0.8)),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1.5.seconds).shimmer(duration: 2.seconds, delay: 1.seconds),
            const SizedBox(height: 24),
            Text("Turn On Wi-Fi", style: ClientTheme.themeData.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: ClientTheme.textDark)),
            const SizedBox(height: 12),
            Text("Enable Wi-Fi to scan and connect\nto your device hotspot.", textAlign: TextAlign.center, style: TextStyle(color: ClientTheme.textLight, height: 1.4, fontSize: 14)),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: ClientTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))], gradient: LinearGradient(colors: [ClientTheme.primaryColor, ClientTheme.primaryColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Iconsax.flash_1, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text("ENABLE WI-FI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: _initializeWifi, child: const Text("I have already enabled it", style: TextStyle(fontSize: 13, decoration: TextDecoration.underline, decorationColor: Colors.black12))),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Device Information", style: TextStyle(color: ClientTheme.textDark, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _deviceIdController, readOnly: true, decoration: InputDecoration(labelText: "Device ID", filled: true, fillColor: Colors.grey.shade100, prefixIcon: const Icon(Iconsax.mobile), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 20),
          Text("Manual Configuration", style: TextStyle(color: ClientTheme.textDark, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _getCmdController,
                  decoration: InputDecoration(
                    labelText: "Command",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _sendCommand(_getCmdController.text),
                style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.secondaryColor),
                child: const Text("SEND", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Communication Log", style: TextStyle(color: ClientTheme.textDark, fontWeight: FontWeight.bold)),
              if(_isSocketConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text("LIVE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 8),
          Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: ListView.builder(
                  controller: _logScrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(_logs[index], style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'Courier')),
                  )
              )
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isCheckingInternet ? null : _handleSaveAndNext,
              icon: _isCheckingInternet
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Iconsax.save_2, color: Colors.white),
              label: Text(
                  _isCheckingInternet ? "SYNCING..." : "SAVE & CONFIGURE CHANNELS",
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNetworkList() {
    if (_networks.isEmpty && !_isScanning) {
      return Center(child: Text("No networks found", style: TextStyle(color: ClientTheme.textLight)));
    }
    return RefreshIndicator(
      onRefresh: _scanWifi,
      color: ClientTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _networks.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemBuilder: (context, index) {
          final net = _networks[index];
          bool isCurrent = net.ssid == _currentSSID && _currentSSID != null;
          bool isSaved = _savedPasswords.containsKey(net.ssid);
          bool isOpen = net.capabilities?.toUpperCase().contains("WPA") == false;
          return AnimatedContainer(
            duration: 300.ms,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: isCurrent ? ClientTheme.primaryColor.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isCurrent ? ClientTheme.primaryColor : Colors.grey.shade200, width: isCurrent ? 1.5 : 1), boxShadow: isCurrent ? [BoxShadow(color: ClientTheme.primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : []),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isCurrent ? ClientTheme.primaryColor : Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Iconsax.wifi, color: isCurrent ? Colors.white : Colors.grey.shade600, size: 20)),
              title: Text(net.ssid ?? "Hidden Network", style: TextStyle(fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600, color: isCurrent ? ClientTheme.textDark : ClientTheme.textDark.withOpacity(0.8))),
              subtitle: Padding(padding: const EdgeInsets.only(top: 6.0), child: Wrap(spacing: 6, children: [if (isCurrent) _badge("Connected", ClientTheme.success), if (isSaved && !isCurrent) _badge("Saved", Colors.green), if (isOpen) _badge("Open", Colors.orange) else Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.lock_outline, size: 12, color: ClientTheme.textLight))])),
              trailing: isCurrent ? Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: ClientTheme.success, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14)) : Icon(Iconsax.arrow_right_3, size: 16, color: ClientTheme.textLight),
              onTap: () => _handleNetworkTap(net),
            ),
          );
        },
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  void _showPasswordDialog(String ssid) {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [const Icon(Icons.lock, size: 18), const SizedBox(width: 8), Text("Connect to $ssid", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            content: TextField(controller: controller, obscureText: true, autofocus: true, decoration: InputDecoration(hintText: "Enter Password", filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: ClientTheme.textLight))),      ElevatedButton(onPressed: () { Navigator.pop(context); _connectToWifi(ssid, controller.text); }, style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Connect")),      ],
    ),
    );
  }
}