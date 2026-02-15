// [UPDATE] lib/device_configure.dart

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
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
      if (provider.selectedDeviceRecNo != null) {
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
    return "${ApiConstants.baseUrl}/client_api.php";
  }

  // === API CALLS ===

  Future<void> _fetchInputTypes() async {
    try {
      final types = await _inputTypeService.getAllInputTypes();
      if (mounted) {
        setState(() => _inputTypes = types);
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
          // Directly ensure we are in channel config mode
          provider.goToChannelConfiguration();
        } else {
          provider.setChannels([]);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("WARNING: ${result['error'] ?? 'NO CHANNELS FOUND.'}")),
            );
          }
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
          final recNo = Provider.of<ClientProvider>(context, listen: false).selectedDeviceRecNo;
          if (recNo != null) await _fetchChannels(recNo);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CHANNEL UPDATED!")));
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("UPDATE FAILED: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientProvider>(
      builder: (context, provider, child) {
        // 1. If no device is selected, show empty state
        if (provider.selectedDeviceRecNo == null) {
          return _buildDeviceNotSelectedState(provider);
        }

        // 2. Load Channel View directly
        return _buildChannelConfigurationView(provider);
      },
    );
  }

  // === VIEW: DEVICE NOT SELECTED ===
  Widget _buildDeviceNotSelectedState(ClientProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.devices, size: 48, color: ClientTheme.textLight),
          const SizedBox(height: 16),
          Text("No Device Selected", style: ClientTheme.themeData.textTheme.titleLarge),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: provider.clearSelection,
            icon: const Icon(Iconsax.arrow_left, color: ClientTheme.primaryColor),
            label: const Text("Select Device", style: TextStyle(color: ClientTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // === VIEW: CHANNEL CONFIGURATION ===
  Widget _buildChannelConfigurationView(ClientProvider provider) {
    final String deviceName = provider.selectedDeviceData?['DeviceName'] ?? 'Selected Device';
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isChannelsLoading) {
      return const Center(child: CircularProgressIndicator(color: ClientTheme.primaryColor));
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: ClientTheme.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text("Quick Start Channels", style: TextStyle(color: ClientTheme.textLight, fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.refresh, color: ClientTheme.primaryColor),
                onPressed: () {
                  if (provider.selectedDeviceRecNo != null) _fetchChannels(provider.selectedDeviceRecNo!);
                },
              ),
              ElevatedButton(
                onPressed: () => _navigateToChannelDataScreen(context, provider.channels),
                style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.secondaryColor),
                child: const Text("VIEW DATA", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildSearchBar(filteredChannels.length),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filteredChannels.isEmpty
              ? _buildEmptyChannelState(defaultChannels.isEmpty)
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: filteredChannels.length,
            itemBuilder: (context, index) => _buildChannelListItem(filteredChannels[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ClientTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClientTheme.textLight.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search Channel...',
          prefixIcon: const Icon(Iconsax.search_normal, size: 20),
          suffixText: '$count Selected',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildChannelListItem(Map<String, dynamic> channel, int index) {
    final String channelName = channel['ChannelName'] ?? 'Unnamed Channel';
    final String channelID = channel['ChannelID'] ?? '#';
    final String graphColorString = channel['Effective_GraphColor']?.toString().replaceAll('#', '') ?? '2563EB';
    final Color colorIndicator = Color(int.parse('FF$graphColorString', radix: 16));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(width: 4, color: colorIndicator),
        title: Text(channelName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("ID: $channelID | Unit: ${channel['Unit'] ?? '-'}"),
        trailing: const Icon(Iconsax.edit, color: ClientTheme.secondaryColor),
        onTap: () {
          showEditChannelDialogFromNewFile(
            context,
                (updatedData) => _updateChannel(updatedData),
            channel,
            _inputTypes,
          );
        },
      ),
    ).animate().fadeIn(delay: (index * 50).ms);
  }

  Widget _buildEmptyChannelState(bool noData) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.danger, size: 48, color: ClientTheme.textLight),
          const SizedBox(height: 16),
          Text(noData ? "No Channels Found" : "No results match your search"),
        ],
      ),
    );
  }

  void _navigateToChannelDataScreen(BuildContext context, List<dynamic> channels) {
    // Use the same robust logic as the UI to filter selected channels
    final selected = channels.where((c) {
      final val = c['IsDefaultSelected'];
      if (val is int) return val == 1;
      if (val is bool) return val == true;
      return false;
    }).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No channels are currently active. Please select/enable channels first."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Ensure the list is explicitly cast to the type expected by ChannelDataScreen
    // Usually List<Map<String, dynamic>>
    final List<Map<String, dynamic>> formattedSelected =
    selected.map((e) => Map<String, dynamic>.from(e)).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChannelDataScreen(selectedChannels: formattedSelected),
      ),
    );
  }
}