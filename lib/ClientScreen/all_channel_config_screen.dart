// [UPDATE] lib/ClientScreen/all_channel_config_screen.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../AdminService/input_type_api_service.dart';
import '../AdminService/client_api_service.dart'; // NEW IMPORT
import '../theme/client_theme.dart';
import '../widgets/constants.dart';

// -------------------------------------------------------------
// === NEW SCREEN: ALL CHANNEL CONFIGURATION (Default Selector) ===
// -------------------------------------------------------------

class AllChannelConfigScreen extends StatefulWidget {
  final int deviceRecNo;
  final VoidCallback onSave;
  final List<dynamic> allChannels; // Pass all channels to initialize state

  const AllChannelConfigScreen({
    super.key,
    required this.deviceRecNo,
    required this.onSave,
    required this.allChannels,
  });

  @override
  State<AllChannelConfigScreen> createState() => _AllChannelConfigScreenState();
}

class _AllChannelConfigScreenState extends State<AllChannelConfigScreen> {
  // Map<MapID, isSelected>
  late Map<int, bool> _channelSelection;
  bool _isSaving = false;

  // NEW: Loading state for auto-refresh
  bool _isLoading = true; // Default true to allow initial setup

  final InputTypeApiService _inputTypeService = InputTypeApiService();
  final ClientApiService _clientApiService = ClientApiService(); // NEW SERVICE

  // Cache input types to prevent refetching
  bool _isInputMasterLoading = true;
  List<Map<String, dynamic>> _inputTypes = [];

  // Local state for all channels to allow real-time updates after edit
  late List<dynamic> _mutableChannels;

  // NEW: Store the channel limit
  int _currentChannelLimit = 0;

  @override
  void initState() {
    super.initState();
    _mutableChannels = [];
    _channelSelection = {};

    // Start the setup sequence: Fetch Limit -> Filter Channels -> Load Data
    _initialSetup();

    _fetchInputTypes(); // FETCH INPUT TYPES ON INIT
  }

  // 閥 NEW: Setup Sequence
  Future<void> _initialSetup() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch the Channel Limit for this device
      _currentChannelLimit = await _clientApiService.getDeviceChannelLimit(widget.deviceRecNo);

      // 2. Load Channels (either from widget or API)
      if (widget.allChannels.isEmpty) {
        await _fetchChannelsFromApi();
      } else {
        // Apply limit to passed channels
        List<dynamic> channels = List.from(widget.allChannels);
        if (_currentChannelLimit > 0 && channels.length > _currentChannelLimit) {
          channels = channels.sublist(0, _currentChannelLimit);
        }
        _initializeData(channels);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Setup Error: $e");
      // Fallback: load whatever we have without limit if error
      if(widget.allChannels.isNotEmpty && _mutableChannels.isEmpty) {
        _initializeData(widget.allChannels);
      }
      setState(() => _isLoading = false);
    }
  }

  // Helper to initialize data structure
  void _initializeData(List<dynamic> channels) {
    _mutableChannels = List<dynamic>.from(channels);
    _channelSelection = {
      for (var c in _mutableChannels)
        (c['MapID'] as int): (c['IsDefaultSelected'] is int
            ? c['IsDefaultSelected'] == 1
            : c['IsDefaultSelected'] as bool? ?? false)
    };
  }

  // 閥 NEW: Fetch Channels directly (Auto-Refresh Logic)
  Future<void> _fetchChannelsFromApi() async {
    if (!mounted) return;
    // Only set loading if not already part of initial setup
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_getApiBaseUrl()),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "GET_CHANNELS",
          "DeviceRecNo": widget.deviceRecNo,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          if (mounted) {
            List<dynamic> fetchedChannels = result['data'];

            // 3. Apply Limit Filter
            if (_currentChannelLimit > 0 && fetchedChannels.length > _currentChannelLimit) {
              fetchedChannels = fetchedChannels.sublist(0, _currentChannelLimit);
            }

            setState(() {
              _initializeData(fetchedChannels);
              _isLoading = false;
            });
          }
        } else {
          throw Exception(result['error'] ?? 'Failed to load channels');
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print("Auto-refresh failed: $e");
      }
    }
  }

  // Fetch Input Types
  Future<void> _fetchInputTypes() async {
    if (!mounted) return;
    setState(() => _isInputMasterLoading = true);
    try {
      final types = await _inputTypeService.getAllInputTypes();
      if (mounted) {
        setState(() {
          _inputTypes = types;
          _isInputMasterLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInputMasterLoading = false);
      }
    }
  }

  String _getApiBaseUrl() {
    return '${ApiConstants.baseUrl}/client_api.php';
  }

  Future<void> _saveDefaultChannelSelection() async {
    setState(() => _isSaving = true);

    final List<int> selectedIds = _channelSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    try {
      final response = await http.post(
        Uri.parse(_getApiBaseUrl()),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "SELECT_CHANNELS",
          "DeviceRecNo": widget.deviceRecNo,
          "ChannelMapIDs": selectedIds.join(','),
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          if (mounted) {
            // Update the local list's IsDefaultSelected based on new selection
            for(var channel in _mutableChannels) {
              channel['IsDefaultSelected'] = _channelSelection[channel['MapID']] == true ? 1 : 0;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${result['data'][0]['ChannelsSelected']} DEFAULT CHANNELS SAVED.")),
            );
            widget.onSave();
          }
        } else {
          throw Exception(result['error'] ?? 'SAVING DEFAULT SELECTION FAILED.');
        }
      } else {
        throw Exception("SERVER ERROR: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("FAILED TO SAVE DEFAULT SELECTION: $e")),
        );
      }
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  // Handle update from the edit dialog
  void _handleChannelUpdate(Map<String, dynamic> updatedData) {
    _updateChannelApi(updatedData);

    final index = _mutableChannels.indexWhere((c) => c['MapID'] == updatedData['MapID']);
    if (index != -1) {
      final Map<String, dynamic> oldChannel = Map<String, dynamic>.from(_mutableChannels[index]);

      oldChannel['ChannelName'] = updatedData['ChannelName'];
      oldChannel['Client_LowLimits'] = updatedData['Client_LowLimits'];
      oldChannel['Client_HighLimits'] = updatedData['Client_HighLimits'];
      oldChannel['Client_AlarmColor'] = updatedData['Client_AlarmColor'];
      oldChannel['Client_GraphColor'] = updatedData['Client_GraphColor'];
      oldChannel['Client_Resolution'] = updatedData['Client_Resolution'];
      oldChannel['Client_Offset'] = updatedData['Client_Offset'];
      oldChannel['Client_LowValue'] = updatedData['Client_LowValue'];
      oldChannel['Client_HighValue'] = updatedData['Client_HighValue'];
      oldChannel['ChannelInputType'] = updatedData['ChannelInputType'];

      // Update Effective values
      oldChannel['Effective_LowLimits'] = updatedData['Client_LowLimits']?.toString() ?? oldChannel['Default_LowLimits']?.toString();
      oldChannel['Effective_HighLimits'] = updatedData['Client_HighLimits']?.toString() ?? oldChannel['Default_HighLimits']?.toString();
      oldChannel['Effective_AlarmColor'] = updatedData['Client_AlarmColor'] ?? oldChannel['Default_AlarmColor'];
      oldChannel['Effective_GraphColor'] = updatedData['Client_GraphColor'] ?? oldChannel['Default_GraphColor'];
      oldChannel['Effective_Resolution'] = updatedData['Client_Resolution'] ?? oldChannel['Default_Resolution'];
      oldChannel['Effective_Offset'] = updatedData['Client_Offset'] ?? oldChannel['Default_Offset'];
      oldChannel['Effective_LowValue'] = updatedData['Client_LowValue'] ?? oldChannel['Default_LowValue'];
      oldChannel['Effective_HighValue'] = updatedData['Client_HighValue'] ?? oldChannel['Default_HighValue'];

      setState(() {
        _mutableChannels[index] = oldChannel;
      });
    }
  }

  Future<void> _updateChannelApi(Map<String, dynamic> channelData) async {
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
          "ChannelInputType": channelData['ChannelInputType'],
        }),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] != 'success') {
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

  // Button to Select/Deselect All Channels
  Widget _buildSelectAllButton() {
    final bool isAllSelected = _channelSelection.isNotEmpty && _channelSelection.values.every((isSelected) => isSelected);

    return TextButton.icon(
      onPressed: () {
        setState(() {
          // If all are selected, deselect all. Otherwise, select all.
          final newValue = !isAllSelected;
          _channelSelection.updateAll((key, value) => newValue);
        });
      },
      icon: Icon(
        isAllSelected ? Iconsax.close_square : Iconsax.tick_square,
        size: 18,
        color: ClientTheme.primaryColor,
      ),
      label: Text(
        isAllSelected ? "Deselect All" : "Select All",
        style: GoogleFonts.poppins(
          color: ClientTheme.primaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: ClientTheme.primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTopSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveDefaultChannelSelection,
      icon: _isSaving
          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Iconsax.save_add, size: 16),
      label: Text(
        _isSaving ? "Saving..." : "Save Selection (${_channelSelection.values.where((v) => v).length})",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: ClientTheme.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show Loader when Auto-Refreshing or Loading Inputs
    if (_isLoading || _isInputMasterLoading) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: ClientTheme.primaryColor),
          const SizedBox(height: 16),
          Text(_isLoading ? "Checking Channel Limits..." : "Loading Configuration...",
              style: ClientTheme.themeData.textTheme.titleMedium),
        ],
      ));
    }

    final channels = _mutableChannels;

    return Scaffold(
      backgroundColor: ClientTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Channel Setup",
                        style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: ClientTheme.textDark),
                      ),
                      // Optional: Show limit indicator
                      if (_currentChannelLimit > 0)
                        Text(
                          "Access Restricted to First $_currentChannelLimit Channels",
                          style: TextStyle(fontSize: 10, color: ClientTheme.error, fontWeight: FontWeight.bold),
                        )
                    ],
                  ),
                ),
                // Select All Button here
                const SizedBox(width: 8),
                _buildSelectAllButton(),
                const SizedBox(width: 8),
                _buildTopSaveButton(),
              ],
            ),
          ),

          Expanded(
            child: channels.isEmpty
                ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("No channels available.", style: ClientTheme.themeData.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    // Retry Button
                    ElevatedButton.icon(
                      onPressed: _initialSetup,
                      icon: const Icon(Iconsax.refresh, size: 18),
                      label: const Text("Retry"),
                    )
                  ],
                )
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                final mapID = channel['MapID'] as int;
                final channelID= channel['ChannelID'] ;
                final isSelected = _channelSelection[mapID] ?? false;

                final String lowLimits = channel['Effective_LowLimits']?.toString() ?? 'N/A';
                final String highLimits = channel['Effective_HighLimits']?.toString() ?? 'N/A';

                final String graphColorString = channel['Effective_GraphColor']?.toString().replaceAll('#', '') ?? '2563EB';
                final Color colorIndicator = Color(int.parse('FF$graphColorString', radix: 16));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                      onTap: () {
                        _showChannelDetailsDialog(context, channel, _inputTypes);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 60,
                              decoration: BoxDecoration(
                                color: colorIndicator,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ClientTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "$channelID",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      Flexible(
                                        child: Text(
                                          channel['ChannelName'] ?? 'Unnamed Channel',
                                          style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: ClientTheme.textDark),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: ClientTheme.success.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: ClientTheme.success.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            "SELECTED",
                                            style: TextStyle(
                                              color: ClientTheme.success,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Limits: $lowLimits - $highLimits | Unit: ${channel['Unit'] ?? '-'}",
                                    style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(color: ClientTheme.textLight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Iconsax.edit, color: ClientTheme.secondaryColor, size: 22),
                                  tooltip: 'Edit Configuration',
                                  onPressed: () => _showEditChannelDialog(
                                    context,
                                        (updatedData) => _handleChannelUpdate(updatedData),
                                    channel,
                                    _inputTypes,
                                  ),
                                ),
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      _channelSelection[mapID] = val ?? false;
                                    });
                                  },
                                  activeColor: ClientTheme.primaryColor,
                                  checkColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideX(duration: 300.ms, begin: 0.1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // === DETAIL & EDIT DIALOGS (Kept as is, just ensured they work) ===
  // -------------------------------------------------------------

  void _showChannelDetailsDialog(
      BuildContext context,
      Map<String, dynamic> channel,
      List<Map<String, dynamic>> inputTypes,
      ) {
    final String inputTypeName = inputTypes.firstWhere(
            (t) => t['InputTypeID'] == channel['ChannelInputType'],
        orElse: () => {'TypeName': 'Unknown'}
    )['TypeName'];

    final List<Map<String, dynamic>> details = [
      {'label': 'Channel ID', 'value': channel['MapID']?.toString() ?? 'N/A'},
      {'label': 'Input Type', 'value': inputTypeName},
      {'label': 'Unit', 'value': channel['Unit'] ?? 'N/A'},
      {'label': 'Default Selection', 'value': (channel['IsDefaultSelected'] == 1 ? 'Yes' : 'No')},
      {'label': 'Low Limit (Alarm Min)', 'value': channel['Effective_LowLimits']?.toString() ?? 'N/A', 'type': 'effective'},
      {'label': 'High Limit (Alarm Max)', 'value': channel['Effective_HighLimits']?.toString() ?? 'N/A', 'type': 'effective'},
      {'label': 'Offset', 'value': channel['Effective_Offset']?.toString() ?? 'N/A', 'type': 'effective'},
      {'label': 'Resolution', 'value': channel['Effective_Resolution']?.toString() ?? 'N/A', 'type': 'effective'},
      {'label': 'Low Value (Linear)', 'value': channel['Effective_LowValue']?.toString() ?? 'N/A', 'type': 'effective'},
      {'label': 'High Value (Linear)', 'value': channel['Effective_HighValue']?.toString() ?? 'N/A', 'type': 'effective'},
      {'label': 'Graph Color (Effective)', 'value': channel['Effective_GraphColor']?.toString() ?? 'N/A', 'type': 'color'},
      {'label': 'Alarm Color (Effective)', 'value': channel['Effective_AlarmColor']?.toString() ?? 'N/A', 'type': 'color'},
    ];


    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ClientTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Channel Details: ${channel['ChannelName']}",
              style: ClientTheme.themeData.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsSectionHeader("General Information"),
                ...details.sublist(0, 4).map((d) => _buildDetailRow(d['label'] as String, d['value'] as String)),

                _buildSettingsSectionHeader("Effective Configuration"),
                ...details.sublist(4, 10).map((d) => _buildDetailRow(d['label'] as String, d['value'] as String)),

                _buildSettingsSectionHeader("Color Settings"),
                ...details.sublist(10).map((d) => _buildColorDetailRow(d['label'] as String, d['value'] as String)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: ClientTheme.textLight)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(color: ClientTheme.textDark.withOpacity(0.7))),
          Text(value, style: ClientTheme.themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildColorDetailRow(String label, String hex) {
    final cleanHex = hex.replaceAll('#', '');
    Color color = Colors.transparent;
    try {
      color = Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(color: ClientTheme.textDark.withOpacity(0.7))),
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ClientTheme.textLight.withOpacity(0.3)),
                ),
              ),
              const SizedBox(width: 8),
              Text('#$cleanHex', style: ClientTheme.themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditChannelDialog(
      BuildContext context,
      ValueChanged<Map<String, dynamic>> onUpdate,
      Map<String, dynamic> channel,
      List<Map<String, dynamic>> inputTypes,
      ) {
    Map<String, dynamic> tempChannelData = _mapChannelDataForEdit(channel);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {

            Color currentLineColor = Color(int.parse('FF${tempChannelData['Client_GraphColor']?.toString().replaceAll('#', '') ?? '2563EB'}', radix: 16));
            Color currentAlarmColor = Color(int.parse('FF${tempChannelData['Client_AlarmColor']?.toString().replaceAll('#', '') ?? 'FF0000'}', radix: 16));

            bool isLinearInput = _checkLinearity(tempChannelData['ChannelInputType'], inputTypes);

            return AlertDialog(
              backgroundColor: ClientTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.all(24),
              title: Text("Edit Channel: ${tempChannelData['ChannelName']}",
                  style: ClientTheme.themeData.textTheme.titleLarge),

              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSettingsSectionHeader("Channel Identification"),
                      _buildStyledTextFormField(
                        label: 'Channel Name',
                        initialValue: tempChannelData['ChannelName']?.toString() ?? '',
                        defaultValue: 'Channel ${tempChannelData['MapID']}',
                        onSaved: (v) => tempChannelData['ChannelName'] = v,
                        isNumeric: false,
                      ),

                      _buildSettingsSectionHeader("Channel Type & Limits (Unit: ${tempChannelData['Unit']})"),

                      _buildInputTypeDropdown(
                        inputTypes: inputTypes,
                        currentValue: tempChannelData['ChannelInputType'],
                        onChanged: (newId) {
                          setState(() {
                            tempChannelData['ChannelInputType'] = newId;
                            isLinearInput = _checkLinearity(newId, inputTypes);
                          });
                        },

                      ),
                      const SizedBox(height: 16),

                      _buildStyledTextFormField(
                        label: 'Low Limit (Alarm Minimum)',
                        initialValue: tempChannelData['Client_LowLimits']?.toString() ?? '',
                        defaultValue: tempChannelData['Default_LowLimits']?.toString() ?? 'N/A',
                        onSaved: (v) => tempChannelData['Client_LowLimits'] = v,
                      ),
                      _buildStyledTextFormField(
                        label: 'High Limit (Alarm Maximum)',
                        initialValue: tempChannelData['Client_HighLimits']?.toString() ?? '',
                        defaultValue: tempChannelData['Default_HighLimits']?.toString() ?? 'N/A',
                        onSaved: (v) => tempChannelData['Client_HighLimits'] = v,
                      ),
                      _buildStyledTextFormField(
                        label: 'Offset',
                        initialValue: tempChannelData['Client_Offset']?.toString() ?? '',
                        defaultValue: tempChannelData['Default_Offset']?.toString() ?? 'N/A',
                        onSaved: (v) => tempChannelData['Client_Offset'] = v,
                      ),

                      const SizedBox(height: 20),

                      if (isLinearInput) ...[
                        _buildSettingsSectionHeader("Linear Conversion Settings"),

                        _buildStyledTextFormField(
                          label: 'Low Value',
                          initialValue: tempChannelData['Client_LowValue']?.toString() ?? '',
                          defaultValue: tempChannelData['Default_LowValue']?.toString() ?? 'N/A',
                          onSaved: (v) => tempChannelData['Client_LowValue'] = v,
                        ),
                        _buildStyledTextFormField(
                          label: 'High Value',
                          initialValue: tempChannelData['Client_HighValue']?.toString() ?? '',
                          defaultValue: tempChannelData['Default_HighValue']?.toString() ?? 'N/A',
                          onSaved: (v) => tempChannelData['Client_HighValue'] = v,
                        ),
                        _buildStyledTextFormField(
                          label: 'Resolution',
                          initialValue: tempChannelData['Client_Resolution']?.toString() ?? '',
                          defaultValue: tempChannelData['Default_Resolution']?.toString() ?? 'N/A',
                          onSaved: (v) => tempChannelData['Client_Resolution'] = v,
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildSettingsSectionHeader("Color Configuration"),

                      _buildColorPickerControl(
                        dialogContext,
                        title: "Graph Line Color",
                        currentColor: currentLineColor,
                        onColorSelected: (color) {
                          setState(() {
                            currentLineColor = color;
                            tempChannelData['Client_GraphColor'] = color.value.toRadixString(16).substring(2).toUpperCase();
                          });
                        },
                        defaultHex: tempChannelData['Default_GraphColor'] ?? '2563EB',
                      ),
                      const SizedBox(height: 12),

                      _buildColorPickerControl(
                        dialogContext,
                        title: "Alarm Color",
                        currentColor: currentAlarmColor,
                        onColorSelected: (color) {
                          setState(() {
                            currentAlarmColor = color;
                            tempChannelData['Client_AlarmColor'] = color.value.toRadixString(16).substring(2).toUpperCase();
                          });
                        },
                        defaultHex: tempChannelData['Default_AlarmColor'] ?? 'FF0000',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: ClientTheme.textLight)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.of(context).pop();

                      onUpdate({
                        ...tempChannelData,
                        'ChannelName': tempChannelData['ChannelName'],
                        'Client_LowLimits': double.tryParse(tempChannelData['Client_LowLimits'] as String? ?? '0.0'),
                        'Client_HighLimits': double.tryParse(tempChannelData['Client_HighLimits'] as String? ?? '100.0'),
                        'Client_Offset': double.tryParse(tempChannelData['Client_Offset'] as String? ?? '0.0'),
                        'Client_LowValue': isLinearInput ? double.tryParse(tempChannelData['Client_LowValue'] as String? ?? '0.0') : null,
                        'Client_HighValue': isLinearInput ? double.tryParse(tempChannelData['Client_HighValue'] as String? ?? '0.0') : null,
                        'Client_Resolution': isLinearInput ? int.tryParse(tempChannelData['Client_Resolution'] as String? ?? '0') : null,
                        'ChannelInputType': int.tryParse(tempChannelData['ChannelInputType']?.toString() ?? '0') ?? null,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClientTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _mapChannelDataForEdit(Map<String, dynamic> channel) {
    return {
      'MapID': channel['MapID'],
      'ChannelName': channel['ChannelName'],
      'Unit': channel['Unit'],
      'ChannelInputType': channel['ChannelInputType'],

      'Client_LowLimits': channel['Client_LowLimits'] ?? channel['Effective_LowLimits'],
      'Client_HighLimits': channel['Client_HighLimits'] ?? channel['Effective_HighLimits'],
      'Client_AlarmColor': channel['Client_AlarmColor'] ?? channel['Effective_AlarmColor'] ?? 'FF0000',
      'Client_GraphColor': channel['Client_GraphColor'] ?? channel['Effective_GraphColor'] ?? '2563EB',
      'Client_Offset': channel['Client_Offset'] ?? channel['Effective_Offset'],
      'Client_LowValue': channel['Client_LowValue'] ?? channel['Effective_LowValue'],
      'Client_HighValue': channel['Client_HighValue'] ?? channel['Effective_HighValue'],
      'Client_Resolution': channel['Client_Resolution'] ?? channel['Effective_Resolution'],

      'Default_LowLimits': channel['Default_LowLimits'],
      'Default_HighLimits': channel['Default_HighLimits'],
      'Default_AlarmColor': channel['Default_AlarmColor'] ?? 'FF0000',
      'Default_GraphColor': channel['Default_GraphColor'] ?? '2563EB',
      'Default_Offset': channel['Default_Offset'],
      'Default_LowValue': channel['Default_LowValue'],
      'Default_HighValue': channel['Default_HighValue'],
      'Default_Resolution': channel['Default_Resolution'],
    };
  }

  bool _checkLinearity(dynamic inputTypeId, List<Map<String, dynamic>> inputTypes) {
    if (inputTypeId == null) return false;
    final selectedType = inputTypes.firstWhere(
            (t) => t['InputTypeID'] == inputTypeId,
        orElse: () => {'IsLinear': 0}
    );
    return selectedType['IsLinear'] == 1;
  }

  Widget _buildInputTypeDropdown({
    required List<Map<String, dynamic>> inputTypes,
    required dynamic currentValue,
    required ValueChanged<int?> onChanged,
  }) {
    final selectedInputType = inputTypes.firstWhere(
            (t) => t['InputTypeID'] == currentValue,
        orElse: () => {'TypeName': 'Select Type', 'InputTypeID': null, 'IsLinear': 0}
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ClientTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClientTheme.textLight.withOpacity(0.1)),
      ),
      child: DropdownButtonFormField<int>(
        value: selectedInputType['InputTypeID'] as int?,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        hint: Text('Select Input Type', style: ClientTheme.themeData.textTheme.bodyMedium),
        items: inputTypes.map<DropdownMenuItem<int>>((type) {
          return DropdownMenuItem<int>(
            value: type['InputTypeID'] as int,
            child: Text(
              '${type['TypeName']} ${type['IsLinear'] == 1 ? ' (Linear)' : ' (Non-Linear)'}',
              style: ClientTheme.themeData.textTheme.bodyMedium,
            ),
          );
        }).toList(),
        onChanged: (int? newValue) {
          onChanged(newValue);
        },
        validator: (value) => value == null ? 'Please select an input type' : null,
      ),
    );
  }

  Widget _buildSettingsSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: ClientTheme.secondaryColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: ClientTheme.themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: ClientTheme.textDark), overflow: TextOverflow.ellipsis),
          const Expanded(child: Divider(indent: 10)),
        ],
      ),
    );
  }

  Widget _buildStyledTextFormField({
    required String label,
    required String initialValue,
    required String defaultValue,
    required FormFieldSetter<String> onSaved,
    bool isNumeric = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ClientTheme.themeData.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: ClientTheme.textDark)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: initialValue,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            textCapitalization: isNumeric ? TextCapitalization.none : TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Default: $defaultValue',
              hintStyle: TextStyle(color: ClientTheme.textLight.withOpacity(0.6), fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
              fillColor: ClientTheme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Value cannot be empty';
              if (isNumeric && double.tryParse(v) == null) return 'Enter a valid number';
              return null;
            },
            onSaved: onSaved,
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerControl(
      BuildContext context, {
        required String title,
        required Color currentColor,
        required ValueChanged<Color> onColorSelected,
        required String defaultHex,
      }) {
    final cleanDefaultHex = defaultHex.replaceAll('#', '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ClientTheme.themeData.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: ClientTheme.textDark)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Color pickerColor = currentColor;
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: currentColor,
                          onColorChanged: (color) => pickerColor = color,
                          paletteType: PaletteType.hueWheel,
                          pickerAreaHeightPercent: 0.7,
                          enableAlpha: false,
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        TextButton(
                          child: const Text('Select'),
                          onPressed: () {
                            onColorSelected(pickerColor);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ClientTheme.textLight.withOpacity(0.2), width: 2),
                    boxShadow: [BoxShadow(color: currentColor.withOpacity(0.3), blurRadius: 4)]
                ),
              ),
            ),

            Text("#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}",
                style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: ClientTheme.textDark)),

            TextButton(
              onPressed: () {
                final defaultColor = Color(int.parse('FF$cleanDefaultHex', radix: 16));
                onColorSelected(defaultColor);
              },
              child: Text('Reset to Default', style: TextStyle(color: ClientTheme.textLight.withOpacity(0.8))),
            ),
          ],
        ),
      ],
    );
  }
}

void showEditChannelDialogFromNewFile(
    BuildContext context,
    ValueChanged<Map<String, dynamic>> onUpdate,
    Map<String, dynamic> channel,
    List<Map<String, dynamic>> inputTypes,
    ) {
  _AllChannelConfigScreenState()._showEditChannelDialog(context, onUpdate, channel, inputTypes);
}