// [UPDATE] lib/device_configure.dart

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/client_theme.dart';
import '../provider/client_provider.dart';
import '../AdminService/input_type_api_service.dart';

import '../widgets/constants.dart';
import 'ViewData/channel_data_Screen.dart';
import 'all_channel_config_screen.dart';

final GlobalKey<DeviceConfigScreenState> deviceConfigScreenKey = GlobalKey<DeviceConfigScreenState>();

class DeviceConfigScreen extends StatefulWidget {
  const DeviceConfigScreen({required Key key}) : super(key: key);

  @override
  State<DeviceConfigScreen> createState() => DeviceConfigScreenState();
}

class DeviceConfigScreenState extends State<DeviceConfigScreen> {
  bool _isChannelsLoading = false;
  bool _isConnecting = false;

  bool _isInputMasterLoading = false;
  List<Map<String, dynamic>> _inputTypes = [];
  final InputTypeApiService _inputTypeService = InputTypeApiService();

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInputTypes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ClientProvider>(context, listen: false);
      final isMobile = MediaQuery.of(context).size.width < 600;

      if (provider.selectedDeviceRecNo != null && !isMobile) {
        _fetchChannels(provider.selectedDeviceRecNo!);
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getApiBaseUrl() {
    return  "${ApiConstants.baseUrl}/client_api.php";
  }

  void _startConnectionSimulation() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    final recNo = provider.selectedDeviceRecNo;
    if (recNo == null || _isChannelsLoading || _isConnecting) return;

    setState(() => _isConnecting = true);
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      setState(() => _isConnecting = false);
      _fetchChannels(recNo);
    }
  }

  // === API CALLS ===

  Future<void> _fetchInputTypes() async {
    if (!mounted) return;
    try {
      final types = await _inputTypeService.getAllInputTypes();
      if (mounted) {
        setState(() {
          _inputTypes = types;
        });
      }
    } catch (e) {
      debugPrint("Failed to load input types: $e");
    }
  }

  Future<void> _fetchChannels(int deviceRecNo) async {
    if (!mounted) return;
    setState(() => _isChannelsLoading = true);
    final provider = Provider.of<ClientProvider>(context, listen: false);
    try {
      final response = await http.post(
        Uri.parse(_getApiBaseUrl()),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "GET_CHANNELS",
          "DeviceRecNo": deviceRecNo,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          final List<dynamic> fetchedChannels = result['data'] ?? [];
          provider.setChannels(fetchedChannels);
          provider.goToChannelConfiguration();
        } else {
          provider.setChannels([]);
          provider.goToChannelConfiguration();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("WARNING: ${result['error'] ?? 'NO CHANNELS FOUND.'}")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("CHANNEL SERVER ERROR: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("CHANNEL CONNECTION FAILED: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChannelsLoading = false);
      }
    }
  }

  Future<void> _updateChannel(Map<String, dynamic> channelData) async {
    try {
      final response = await http.post(
        Uri.parse(_getApiBaseUrl()),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "UPDATE_CHANNEL",
          "MapID": channelData['MapID'],
          "TargetAlarmMin": channelData['Client_LowLimits'] ?? channelData['Effective_LowLimits'] ?? "",
          "TargetAlarmMax": channelData['Client_HighLimits'] ?? channelData['Effective_HighLimits'] ?? "",
          "TargetAlarmColour": channelData['Client_AlarmColor'] ?? channelData['Effective_AlarmColor'] ?? "",
          "GraphLineColour": channelData['Client_GraphColor'] ?? channelData['Effective_GraphColor'] ?? "",
          "ChannelName": channelData['ChannelName'] ?? "",
          "Resolution": channelData['Client_Resolution'] ?? channelData['Effective_Resolution'],
          "Offset": channelData['Client_Offset'] ?? channelData['Effective_Offset'],
          "LowValue": channelData['Client_LowValue'] ?? channelData['Effective_LowValue'],
          "HighValue": channelData['Client_HighValue'] ?? channelData['Effective_HighValue'],
          "ChannelInputType": channelData['ChannelInputType'] ?? channelData['ChannelInputType'],
        }),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          if (mounted) {
            final recNo = Provider.of<ClientProvider>(context, listen: false).selectedDeviceRecNo;
            if (recNo != null) {
              await _fetchChannels(recNo);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("CHANNEL UPDATED SUCCESSFULLY!")),
            );
          }
        } else {
          throw Exception(result['error'] ?? 'UPDATE FAILED.');
        }
      } else {
        throw Exception("SERVER ERROR: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("UPDATE FAILED: $e")),
        );
      }
    }
  }

  // === CORE BUILD METHOD ===
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Consumer<ClientProvider>(
      builder: (context, provider, child) {
        if (provider.selectedDeviceRecNo == null) {
          return _buildDeviceNotSelectedState(provider);
        }
        if (provider.currentStep == DeviceSetupStep.wifiConfiguration && isMobile) {
          return _buildWifiConfigurationView(provider);
        }

        if (provider.currentStep == DeviceSetupStep.channelConfiguration || !isMobile) {
          return _buildChannelConfigurationView(provider);
        }

        return _buildWifiConfigurationView(provider);
      },
    );
  }

  // === VIEW 1: DEVICE NOT SELECTED ===
  Widget _buildDeviceNotSelectedState(ClientProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.devices, size: 48, color: ClientTheme.textLight),
          const SizedBox(height: 16),
          Text(
            "No Device Selected",
            style: ClientTheme.themeData.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            "Please return to the Devices menu to select a device.",
            style: ClientTheme.themeData.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: provider.clearSelection,
            icon: Icon(Iconsax.arrow_left, color: ClientTheme.primaryColor),
            label: Text("Select Device", style: TextStyle(color: ClientTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // --- Helper for Circular Indicator ---
  Widget _buildCircularIndicator({required bool isConnecting, required String label}) {
    final statusColor = isConnecting ? ClientTheme.secondaryColor : ClientTheme.primaryColor;
    final content = Container(
      width: 150, height: 150,
      decoration: BoxDecoration(
          color: ClientTheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            )
          ]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isConnecting ? Iconsax.activity : Iconsax.routing, size: 48, color: statusColor),
          const SizedBox(height: 8),
          Text(
            isConnecting ? "Connecting..." : label,
            style: ClientTheme.themeData.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return SizedBox(
      width: 220, height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isConnecting)
            Container(
              width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor.withOpacity(0.1)),
            ).animate(onPlay: (controller) => controller.repeat()).scale(delay: 50.ms, duration: 1500.ms).fade(begin: 1.0, end: 0.0),
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withOpacity(0.05),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 10),
            ),
          ),
          content,
        ],
      ),
    );
  }

  // === VIEW 2: WIFI CONFIGURATION ===
  Widget _buildWifiConfigurationView(ClientProvider provider) {
    final String deviceName = provider.selectedDeviceData?['DeviceName'] ?? 'Selected Device';

    final wifiConnectButton = GestureDetector(
      onTap: (_isChannelsLoading || _isConnecting) ? null : () { _startConnectionSimulation(); },
      child: Container(
        height: 60, width: double.infinity,
        decoration: BoxDecoration(
          color: ClientTheme.primaryColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: ClientTheme.primaryColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        alignment: Alignment.center,
        child: (_isChannelsLoading || _isConnecting)
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            const SizedBox(width: 12),
            Text(_isConnecting ? "Connecting Device..." : "Loading Channels...", style: ClientTheme.themeData.textTheme.labelLarge),
          ],
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.wifi, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text("Connect to Wi-Fi", style: ClientTheme.themeData.textTheme.labelLarge),
          ],
        ),
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircularIndicator(isConnecting: _isConnecting, label: "Ready to Connect"),
            const SizedBox(height: 48),
            Text("Configuring: $deviceName", style: ClientTheme.themeData.textTheme.displayMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text("Press the button below to start the Wi-Fi pairing process.", style: ClientTheme.themeData.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 48),
            wifiConnectButton,
            const SizedBox(height: 20),
            TextButton(
              onPressed: (_isChannelsLoading || _isConnecting) ? null : () {
                final recNo = provider.selectedDeviceRecNo;
                if (recNo != null) _fetchChannels(recNo);
              },
              child: Text("Skip Wi-Fi Configuration", style: TextStyle(color: ClientTheme.textLight)),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: provider.clearSelection,
              icon: Icon(Iconsax.arrow_left, color: ClientTheme.textLight, size: 18),
              label: Text("Change Device", style: TextStyle(color: ClientTheme.textLight)),
            ),
          ],
        ),
      ),
    );
  }

  // === VIEW 3: CHANNEL CONFIGURATION ===
  Widget _buildChannelConfigurationView(ClientProvider provider) {
    final String deviceName = provider.selectedDeviceData?['DeviceName'] ?? 'Selected Device';
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isChannelsLoading) {
      return Center(child: CircularProgressIndicator(color: ClientTheme.primaryColor));
    }

    final List<dynamic> defaultChannels = provider.channels
        .where((c) => (c['IsDefaultSelected'] is int ? c['IsDefaultSelected'] == 1 : c['IsDefaultSelected'] as bool? ?? false))
        .toList();

    final filteredChannels = defaultChannels.where((channel) {
      final channelName = channel['ChannelName']?.toString().toLowerCase() ?? '';
      return channelName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: isMobile ? 16.0 : 0.0, right: isMobile ? 16.0 : 0.0, top: 16.0, bottom: isMobile ? 0.0 : 16.0),
          child: isMobile
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      deviceName,
                      style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, color: ClientTheme.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // RELOAD BUTTON
                  IconButton(
                    icon: const Icon(Iconsax.refresh, color: ClientTheme.primaryColor),
                    onPressed: () {
                      final recNo = provider.selectedDeviceRecNo;
                      if (recNo != null) _fetchChannels(recNo);
                    },
                    tooltip: 'Refresh Channels',
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToChannelDataScreen(context, provider.channels),
                    icon: const Icon(Iconsax.activity, color: Colors.white, size: 18),
                    label: Text("VIEW DATA", style: ClientTheme.themeData.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.secondaryColor, elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text("Quick Start Channels", style: TextStyle(color: ClientTheme.textLight, fontSize: 14)),
              ),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text("Device Channels Overview", style: ClientTheme.themeData.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: ClientTheme.textDark)),
                      const SizedBox(width: 16),
                      // RELOAD BUTTON
                      IconButton(
                          onPressed: () {
                            final recNo = provider.selectedDeviceRecNo;
                            if (recNo != null) _fetchChannels(recNo);
                          },
                          icon: Icon(Iconsax.refresh, color: ClientTheme.primaryColor)
                      )
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToChannelDataScreen(context, provider.channels),
                    icon: const Icon(Iconsax.activity, color: Colors.white, size: 22),
                    label: Text("VIEW DATA", style: ClientTheme.themeData.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.secondaryColor, elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("Monitor the 'Quick Start' channel set for: $deviceName.", style: ClientTheme.themeData.textTheme.titleMedium?.copyWith(color: ClientTheme.textLight)),
            ],
          ),
        ),

        if (isMobile) const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 0.0),
          child: _buildSearchBar(defaultChannels.length),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: filteredChannels.isEmpty
              ? _buildEmptyChannelState(defaultChannels.isEmpty)
              : ListView.builder(
            itemCount: filteredChannels.length,
            itemBuilder: (context, index) {
              final channel = filteredChannels[index];
              return _buildChannelListItem(channel, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(int defaultChannelsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ClientTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClientTheme.textLight.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: ClientTheme.textDark.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: ClientTheme.themeData.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Search Channel by Name...',
                hintStyle: ClientTheme.themeData.textTheme.titleMedium?.copyWith(color: ClientTheme.textLight.withOpacity(0.6), fontSize: 16),
                prefixIcon: Icon(Iconsax.search_normal, color: ClientTheme.primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: Icon(Iconsax.close_circle, color: ClientTheme.textLight), onPressed: () { _searchController.clear(); setState(() {}); })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: ClientTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$defaultChannelsCount Selected', style: ClientTheme.themeData.textTheme.labelMedium?.copyWith(color: ClientTheme.primaryColor, fontWeight: FontWeight.w700)),
          )
        ],
      ),
    );
  }

  // === [UPDATED] CHANNEL LIST ITEM MATCHING ALL_CHANNEL_CONFIG_SCREEN ===
  Widget _buildChannelListItem(Map<String, dynamic> channel, int index) {
    final String channelName = channel['ChannelName'] ?? 'Unnamed Channel';
    final String channelID = channel['ChannelID'] ?? '#';

    final String lowLimits = channel['Effective_LowLimits']?.toString() ?? 'N/A';
    final String highLimits = channel['Effective_HighLimits']?.toString() ?? 'N/A';

    final String graphColorString = channel['Effective_GraphColor']?.toString().replaceAll('#', '') ?? '2563EB';
    final Color colorIndicator = Color(int.parse('FF$graphColorString', radix: 16));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // MATCHING STYLE: Card with Elevation and Border
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: ClientTheme.textLight.withOpacity(0.1),
              width: 1.0,
            )
        ),
        color: ClientTheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // Option: You can add an onTap here if you want tapping the whole card to do something,
          // but for now, we keep the edit button as the primary interaction.
          onTap: () {
            // Optional: Open edit dialog on tap of the whole card
            showEditChannelDialogFromNewFile(
              context,
                  (updatedData) => _updateChannel(updatedData),
              channel,
              _inputTypes,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              children: [
                // 1. VERTICAL COLOR STRIP
                Container(
                  width: 8,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorIndicator,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. CONTENT (Title, Badge, Subtitle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // ID BADGE (Beautiful Style)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ClientTheme.primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              " $channelID",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // CHANNEL NAME
                          Flexible(
                            child: Text(
                              channelName,
                              style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: ClientTheme.textDark
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // SUBTITLE: Limits | Unit
                      Text(
                        "Limits: $lowLimits - $highLimits | Unit: ${channel['Unit'] ?? '-'}",
                        style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(
                            color: ClientTheme.textLight
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. ACTIONS (Edit Button)
                IconButton(
                  icon: const Icon(Iconsax.edit, color: ClientTheme.secondaryColor, size: 22),
                  tooltip: 'Edit Configuration',
                  onPressed: () {
                    showEditChannelDialogFromNewFile(
                      context,
                          (updatedData) => _updateChannel(updatedData),
                      channel,
                      _inputTypes,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideX(duration: 300.ms, begin: 0.1),
    );
  }

  Widget _buildEmptyChannelState(bool isFiltered) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isFiltered ? Iconsax.search_status : Iconsax.chart_fail, size: 48, color: ClientTheme.textLight),
          const SizedBox(height: 16),
          Text(isFiltered ? "No Matching Channel Found" : "No Default Channels Selected", style: ClientTheme.themeData.textTheme.titleLarge),
          const SizedBox(height: 8),


          Text(isFiltered ? "Try a different search term." : "Configure your default channels via 'Configure Channels'.", style: ClientTheme.themeData.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _navigateToChannelDataScreen(BuildContext context, List<dynamic> channels) {
    final List<dynamic> selectedChannels = channels
        .where((c) => (c['IsDefaultSelected'] is int ? c['IsDefaultSelected'] == 1 : c['IsDefaultSelected'] as bool? ?? false))
        .toList();

    if (selectedChannels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one default channel to view data.")));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChannelDataScreen(selectedChannels: selectedChannels)));
  }
}