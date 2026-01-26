// [UPDATE] lib/AdminScreens/ClientScreen/Widget/edit_client_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../AdminService/client_api_service.dart';
import '../../../AdminService/image_upload_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/add_client_dialog.dart';
import 'device_form_dialog.dart';

class EditClientDialog extends StatefulWidget {
  final Map<String, dynamic> client;
  final VoidCallback onSave;
  final int initialTabIndex;
  final String? currentPassword; // [FIX] Added parameter to accept password

  const EditClientDialog({
    super.key,
    required this.client,
    required this.onSave,
    this.initialTabIndex = 0,
    this.currentPassword, // [FIX] Initialize parameter
  });

  @override
  State<EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<EditClientDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ClientApiService _apiService = ClientApiService();
  final ImageUploadService _imageUploadService = ImageUploadService();

  // Tab 1: Client Info
  final _infoFormKey = GlobalKey<FormState>();
  late TextEditingController _companyNameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _passwordDisplayController; // For display only
  bool _isInfoLoading = false;
  String? _currentLogoPath;

  // Logo upload states
  PlatformFile? _logoFile;
  bool _isUploadingLogo = false;
  Uint8List? _logoBytes;

  // Tab 2: Device Info
  bool _isDeviceLoading = true;
  List<DeviceData> _addedDevices = [];
  List<Map<String, dynamic>> _allChannels = [];

  late Map<int, List<int?>?> _selectedChannelsMap;
  Map<int, int> _deviceRecNoMap = {};
  Map<String, int> _channelMapRecNoMap = {};

  static const String _imageBaseUrl =
      "https://storage.googleapis.com/upload-images-34/images/LMS/";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);

    // Init Tab 1
    _companyNameController =
        TextEditingController(text: widget.client['CompanyName']);
    _emailController =
        TextEditingController(text: widget.client['ContactEmail']);
    _addressController =
        TextEditingController(text: widget.client['CompanyAddress']);

    // [FIX] Init Password Controller
    _passwordDisplayController =
        TextEditingController(text: widget.currentPassword ?? "N/A");

    _currentLogoPath = widget.client['LogoPath'];

    // Init Tab 2
    _selectedChannelsMap = {};
    _loadDeviceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordDisplayController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result == null || result.files.first == null) return;
    PlatformFile file = result.files.first;
    final clientName = _companyNameController.text;
    if (clientName.isEmpty) {
      _showErrorSnackbar('Please enter a Company Name before uploading a logo.');
      return;
    }
    setState(() {
      _logoFile = file;
      _isUploadingLogo = true;
    });
    Uint8List imageBytes;
    if (kIsWeb) {
      imageBytes = file.bytes!;
    } else {
      imageBytes = await File(file.path!).readAsBytes();
    }
    _logoBytes = imageBytes;
    try {
      final String uniqueFileName =
      await _imageUploadService.uploadClientLogo(imageBytes, clientName);
      setState(() {
        _currentLogoPath = uniqueFileName;
        _isUploadingLogo = false;
      });
      _showSuccessSnackbar('Logo uploaded successfully!');
    } catch (e) {
      setState(() {
        _isUploadingLogo = false;
        _logoFile = null;
        _logoBytes = null;
      });
      _showErrorSnackbar('Logo upload failed: $e');
    }
  }

  // ... [Keep existing _loadDeviceData, _handleUpdateInfo, etc. logic unchanged] ...
  Future<void> _loadDeviceData() async {
    setState(() => _isDeviceLoading = true);
    try {
      _allChannels = await _apiService.getAllChannels();
      final result =
      await _apiService.getDevicesByClient(widget.client['RecNo']);
      final List<Map<String, dynamic>> devices = result['devices'];
      final List<Map<String, dynamic>> allChannelMappings = result['channels'];

      List<DeviceData> tempDevices = [];
      Map<int, List<int?>?> tempSelectedChannels = {};
      Map<int, int> tempDeviceRecNoMap = {};
      Map<String, int> tempChannelMapRecNoMap = {};

      int sequentialIndex = 0;

      for (final device in devices) {
        if (device['IsActive'] == 0) continue;

        final int channelCount = device['ChannelsCount'] ?? 0;

        tempDevices.add(DeviceData(
          name: device['DeviceName'],
          serial: device['SerialNumber'],
          channelCount: channelCount,
          location: device['Location'] ?? '',
        ));

        tempDeviceRecNoMap[sequentialIndex] = device['RecNo'];

        List<int?> channels =
        channelCount > 0 ? List.filled(channelCount, null) : [];

        final deviceChannels = allChannelMappings
            .where((map) => map['DeviceRecNo'] == device['RecNo'])
            .toList();

        for (var map in deviceChannels) {
          int channelIndex = (map['ChannelIndex'] ?? 1) - 1;
          if (channelIndex >= 0 && channelIndex < channels.length) {
            channels[channelIndex] = map['ChannelRecNo'];
            tempChannelMapRecNoMap["${sequentialIndex}_$channelIndex"] =
            map['RecNo'];
          }
        }
        tempSelectedChannels[sequentialIndex] = channels;
        sequentialIndex++;
      }

      setState(() {
        _addedDevices = tempDevices;
        _selectedChannelsMap = tempSelectedChannels;
        _deviceRecNoMap = tempDeviceRecNoMap;
        _channelMapRecNoMap = tempChannelMapRecNoMap;
        _isDeviceLoading = false;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load device data: $e');
      setState(() => _isDeviceLoading = false);
    }
  }

  Future<void> _handleUpdateInfo() async {
    if (!_infoFormKey.currentState!.validate()) return;
    setState(() => _isInfoLoading = true);
    try {
      await _apiService.updateClientInfo(
        recNo: widget.client['RecNo'],
        companyName: _companyNameController.text,
        companyAddress: _addressController.text,
        contactEmail: _emailController.text,
        logoPath: _currentLogoPath,
      );
      widget.onSave();
      _showSuccessSnackbar('Client info updated!');
    } catch (e) {
      _showErrorSnackbar('Failed to update info: $e');
    } finally {
      if (mounted) setState(() => _isInfoLoading = false);
    }
  }

  void _handleAddNewDevice(DeviceData newDevice) async {
    setState(() => _isDeviceLoading = true);
    try {
      final createdDevice = await _apiService.registerDevice(
        clientRecNo: widget.client['RecNo'],
        deviceName: newDevice.name,
        serialNumber: newDevice.serial,
        channelsCount: newDevice.channelCount,
        location: newDevice.location,
      );

      setState(() {
        _addedDevices.insert(0, newDevice);
        final newMap = <int, List<int?>?>{};
        final newDeviceRecNoMap = <int, int>{};
        final newChannelMapRecNoMap = <String, int>{};

        newMap[0] = List<int?>.filled(newDevice.channelCount, null);
        newDeviceRecNoMap[0] = createdDevice['RecNo'];

        for (int i = 0; i < _addedDevices.length - 1; i++) {
          final newIndex = i + 1;
          newMap[newIndex] = _selectedChannelsMap[i] ?? [];
          if (_deviceRecNoMap.containsKey(i)) {
            newDeviceRecNoMap[newIndex] = _deviceRecNoMap[i]!;
          }
          final oldChannels = _selectedChannelsMap[i];
          if (oldChannels != null) {
            for (int c = 0; c < oldChannels.length; c++) {
              String oldKey = "${i}_$c";
              if (_channelMapRecNoMap.containsKey(oldKey)) {
                newChannelMapRecNoMap["${newIndex}_$c"] =
                _channelMapRecNoMap[oldKey]!;
              }
            }
          }
        }
        _selectedChannelsMap = newMap;
        _deviceRecNoMap = newDeviceRecNoMap;
        _channelMapRecNoMap = newChannelMapRecNoMap;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to add device: $e');
    } finally {
      if (mounted) setState(() => _isDeviceLoading = false);
    }
  }

  void _handleDeleteDevice(int deviceIndex) async {
    setState(() => _isDeviceLoading = true);
    final int? deviceRecNo = _deviceRecNoMap[deviceIndex];
    if (deviceRecNo == null) {
      _showErrorSnackbar('Error: Device ID not found. Please reload.');
      if (mounted) setState(() => _isDeviceLoading = false);
      return;
    }
    try {
      await _apiService.setDeviceActiveStatus(
          recNo: deviceRecNo, isActive: false);
      _showSuccessSnackbar("Device removed. Reloading...");
      await _loadDeviceData();
    } catch (e) {
      _showErrorSnackbar('Failed to remove device: $e');
      if (mounted) setState(() => _isDeviceLoading = false);
    }
  }

  // === AUTO-FILL LOGIC ===
  void _showAutoFillDialog(int deviceIndex) {
    int? selectedStartChannelRecNo;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text("Auto-Fill Channels", style: Theme.of(context).textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select the starting channel. We will fill subsequent channels automatically."),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Start From Channel',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Iconsax.radar_2, color: AppTheme.primaryBlue),
                ),
                items: _allChannels.map((channel) {
                  final String label = channel['ChannelID'] != null
                      ? "${channel['ChannelID']} - ${channel['ChannelName']}"
                      : channel['ChannelName'];
                  return DropdownMenuItem<int>(
                    value: channel['RecNo'],
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  selectedStartChannelRecNo = val;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (selectedStartChannelRecNo != null) {
                  _performAutoFill(deviceIndex, selectedStartChannelRecNo!);
                }
              },
              child: Text("Auto-Fill"),
            ),
          ],
        );
      },
    );
  }

  void _performAutoFill(int deviceIndex, int startRecNo) {
    // ... [Keep existing gap-skipping auto-fill logic] ...
    final startChannel = _allChannels.firstWhere(
            (c) => c['RecNo'] == startRecNo,
        orElse: () => {});

    if (startChannel.isEmpty || startChannel['ChannelID'] == null) {
      _showErrorSnackbar("Invalid starting channel.");
      return;
    }

    String startID = startChannel['ChannelID'].toString();

    final RegExp regex = RegExp(r'^([a-zA-Z]+)(\d+)$');
    final match = regex.firstMatch(startID);

    if (match == null) {
      _showErrorSnackbar("ID format must be letters+numbers (e.g. CH01).");
      return;
    }

    String prefix = match.group(1)!;
    int currentNumber = int.parse(match.group(2)!);
    int padLength = match.group(2)!.length;

    final List<int?> currentSlots = _selectedChannelsMap[deviceIndex] ?? [];
    int filledCount = 0;

    for (int i = 0; i < currentSlots.length; i++) {
      bool foundForThisSlot = false;
      int safetyLimit = 0;

      while (!foundForThisSlot && safetyLimit < 500) {
        String targetID = "$prefix${currentNumber.toString().padLeft(padLength, '0')}";
        currentNumber++;
        safetyLimit++;

        try {
          final targetChannel = _allChannels.firstWhere(
                (c) => c['ChannelID'] == targetID,
            orElse: () => {},
          );

          if (targetChannel.isNotEmpty) {
            if (currentSlots[i] != targetChannel['RecNo']) {
              _handleChannelChange(deviceIndex, i, targetChannel['RecNo']);
              filledCount++;
            } else {
              filledCount++;
            }
            foundForThisSlot = true;
          }
        } catch (e) {
          // Ignore
        }
      }
      if (safetyLimit >= 500) break;
    }
    _showSuccessSnackbar("Auto-filled $filledCount channels.");
  }

  void _handleChannelChange(
      int deviceIndex, int channelIndex, int? newChannelRecNo) async {
    // ... [Keep existing logic] ...
    final List<int?>? selectedChannels = _selectedChannelsMap[deviceIndex];
    if (selectedChannels == null) return;
    final int? deviceRecNo = _deviceRecNoMap[deviceIndex];
    if (deviceRecNo == null) return;
    final String mapKey = "${deviceIndex}_$channelIndex";
    final int? oldChannelMapRecNo = _channelMapRecNoMap[mapKey];
    final int? oldChannelRecNo = selectedChannels[channelIndex];

    final otherSelections = List.from(selectedChannels);
    otherSelections.removeAt(channelIndex);
    if (newChannelRecNo != null && otherSelections.contains(newChannelRecNo)) {
      _showErrorSnackbar('Channel is already assigned to this device.');
      return;
    }

    setState(() {
      _selectedChannelsMap[deviceIndex]![channelIndex] = newChannelRecNo;
    });

    try {
      if (newChannelRecNo == null) {
        if (oldChannelMapRecNo != null) {
          await _apiService.removeChannelFromDevice(oldChannelMapRecNo);
          setState(() {
            _channelMapRecNoMap.remove(mapKey);
          });
        }
      } else {
        if (oldChannelMapRecNo != null) {
          await _apiService.updateAssignedChannel(
            recNo: oldChannelMapRecNo,
            channelRecNo: newChannelRecNo,
            channelIndex: channelIndex + 1,
          );
        } else {
          final newMap = await _apiService.assignChannelToDevice(
            deviceRecNo: deviceRecNo,
            channelRecNo: newChannelRecNo,
            channelIndex: channelIndex + 1,
          );
          setState(() {
            _channelMapRecNoMap[mapKey] = newMap['RecNo'];
          });
        }
      }
    } catch (e) {
      setState(() {
        _selectedChannelsMap[deviceIndex]![channelIndex] = oldChannelRecNo;
      });
      _showErrorSnackbar('Failed to update channel. Reverting changes.');
    }
  }

  // === UPDATED UI CODE STARTS HERE ===

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          title: Text(widget.client['CompanyName'] ?? 'Edit Client',
              style: TextStyle(color: AppTheme.darkText)),
          leading: IconButton(
            icon: Icon(Iconsax.arrow_left, color: AppTheme.darkText),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.bodyText,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(text: 'Client Info', icon: Icon(Iconsax.user)),
              Tab(text: 'Devices', icon: Icon(Iconsax.cpu)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(isMobile: true),
            _buildDevicesTab(),
          ],
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.background,
      surfaceTintColor: AppTheme.background,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              "${widget.client['CompanyName']}",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Iconsax.close_circle, color: AppTheme.bodyText),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.85, // Increased slightly
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: AppTheme.bodyText,
                  indicator: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: const [
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.user, size: 18), SizedBox(width: 8), Text('Client Info')])),
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.cpu, size: 18), SizedBox(width: 8), Text('Manage Devices')])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfoTab(isMobile: false),
                    _buildDevicesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // [UPDATED] Cleaner UI, Smaller Logo, Password Field
  Widget _buildInfoTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _infoFormKey,
        child: Column(
          children: [
            // 1. Sleek Logo Picker
            Center(child: _buildLogoPicker()),
            const SizedBox(height: 32),

            // 2. Info Fields
            if (!isMobile) ...[
              // Desktop: Row for Name and Email
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _companyNameController,
                      label: 'Company Name *',
                      icon: Iconsax.building_4,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _emailController,
                      label: 'Contact Email *',
                      icon: Iconsax.sms,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
                    ),
                  )
                ],
              )
            ] else ...[
              // Mobile: Stacked
              _buildTextFormField(
                controller: _companyNameController,
                label: 'Company Name *',
                icon: Iconsax.building_4,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _emailController,
                label: 'Contact Email *',
                icon: Iconsax.sms,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
              ),
            ],

            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _addressController,
              label: 'Company Address',
              icon: Iconsax.location,
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // [NEW] Password Display Field
            _buildPasswordDisplayField(),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isInfoLoading ? null : _handleUpdateInfo,
              icon: _isInfoLoading
                  ? Container(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Iconsax.save_2, size: 18),
              label: Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // [NEW] Widget for Password Display
  Widget _buildPasswordDisplayField() {
    return TextFormField(
      controller: _passwordDisplayController,
      readOnly: true, // User cannot edit this directly
      style: const TextStyle(
          color: AppTheme.darkText, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: 'Current Password',
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
        prefixIcon: Icon(Iconsax.key, color: AppTheme.accentYellow, size: 20),
        filled: true,
        fillColor: AppTheme.accentYellow.withOpacity(0.1), // Distinct color
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentYellow.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentYellow.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentYellow, width: 2),
        ),
        // Copy Button
        suffixIcon: IconButton(
          icon: Icon(Iconsax.copy, color: AppTheme.bodyText, size: 20),
          tooltip: "Copy Password",
          onPressed: () {
            if (widget.currentPassword != null) {
              Clipboard.setData(ClipboardData(text: widget.currentPassword!));
              _showSuccessSnackbar("Password copied to clipboard");
            }
          },
        ),
      ),
    );
  }

  // [UPDATED] Compact Logo Picker
  Widget _buildLogoPicker() {
    final double size = 110;

    ImageProvider? imageProvider;
    if (_logoBytes != null) {
      imageProvider = MemoryImage(_logoBytes!);
    } else if (_logoFile != null && _logoFile!.path != null) {
      imageProvider = FileImage(File(_logoFile!.path!));
    } else if (_currentLogoPath != null && _currentLogoPath!.isNotEmpty) {
      imageProvider = NetworkImage(_imageBaseUrl + _currentLogoPath!);
    }

    return GestureDetector(
      onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              shape: BoxShape.rectangle, // Keep rectangle for company logos
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderGrey, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
              image: imageProvider != null ? DecorationImage(
                image: imageProvider,
                fit: BoxFit.contain, // Maintain aspect ratio for logos
              ) : null,
            ),
            child: _isUploadingLogo
                ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                : (imageProvider == null
                ? Icon(Iconsax.gallery_add, size: 32, color: AppTheme.bodyText.withOpacity(0.5))
                : null),
          ),

          // Edit Badge
          Container(
            width: 32,
            height: 32,
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(Iconsax.edit_2, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Helper text field builder
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
          color: AppTheme.darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        filled: true,
        fillColor: AppTheme.lightGrey.withOpacity(0.5),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
      ),
    );
  }

  // ... [Keep devices tab and snackbars unchanged] ...
  Widget _buildDevicesTab() {
    if (_isDeviceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isMobile = MediaQuery.of(context).size.width < 900;

    Widget infoBanner = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentYellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.info_circle, size: 20, color: AppTheme.accentYellow),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Drag Channels to Devices or use the Magic Wand (Auto-Fill) to sequentially assign available channels.",
              style: TextStyle(
                color: Colors.brown.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    Widget availableChannelsPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.lightGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGrey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Channels (${_allChannels.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_allChannels.isEmpty)
            const Center(child: Text('No channels available.')),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _allChannels
                    .map((channel) => _buildDraggableChannel(channel))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );

    Widget assignedDevicesPanel = Column(
      children: [
        ElevatedButton.icon(
          onPressed: _showDeviceFormDialog,
          icon: const Icon(Iconsax.add),
          label: const Text('Add New Device'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        Text('Assigned Devices (${_addedDevices.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (_addedDevices.isEmpty)
          Center(
              child: Text('Add a device to begin.',
                  style: TextStyle(color: AppTheme.bodyText))),
        Expanded(
          child: ListView.builder(
            itemCount: _addedDevices.length,
            itemBuilder: (context, deviceIndex) {
              final device = _addedDevices[deviceIndex];
              return _buildDeviceCard(device, deviceIndex, isMobile);
            },
          ),
        ),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          children: [
            infoBanner,
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _showDeviceFormDialog,
                  icon: const Icon(Iconsax.add),
                  label: const Text('Add New Device'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Assigned Devices (${_addedDevices.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _addedDevices.length,
                  itemBuilder: (context, deviceIndex) {
                    final device = _addedDevices[deviceIndex];
                    return _buildDeviceCard(device, deviceIndex, isMobile);
                  },
                ),
              ],
            )
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          infoBanner,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: availableChannelsPanel,
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: assignedDevicesPanel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableChannel(Map<String, dynamic> channel) {
    final int channelRecNo = channel['RecNo'];
    final String channelId = channel['ChannelID'] ?? '';
    final String channelName = channel['ChannelName'] ?? 'Unnamed';

    final String displayLabel = channelId.isNotEmpty
        ? "$channelId - $channelName"
        : channelName;

    bool isAssignedAnywhere = false;
    for (var assignedList in _selectedChannelsMap.values) {
      if (assignedList != null && assignedList.contains(channelRecNo)) {
        isAssignedAnywhere = true;
        break;
      }
    }

    final Color backgroundColor = isAssignedAnywhere
        ? AppTheme.lightGrey
        : AppTheme.accentGreen.withOpacity(0.1);

    final Color textColor = isAssignedAnywhere
        ? AppTheme.bodyText.withOpacity(0.5)
        : AppTheme.accentGreen;

    final Color borderColor = isAssignedAnywhere
        ? Colors.transparent
        : AppTheme.accentGreen.withOpacity(0.3);

    final Widget feedbackWidget = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.radar_2, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(displayLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ).animate().scaleXY(begin: 1.0, end: 1.1),
    );

    return Draggable<int>(
      data: channelRecNo,
      feedback: feedbackWidget,
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Chip(
          label: Text(displayLabel),
          backgroundColor: AppTheme.borderGrey,
          side: BorderSide.none,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAssignedAnywhere ? Iconsax.lock : Iconsax.radar_2, size: 14, color: textColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                displayLabel,
                style: TextStyle(fontWeight: isAssignedAnywhere ? FontWeight.normal : FontWeight.bold, color: textColor, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DeviceData device, int deviceIndex, bool isMobile) {
    final List<int?> selectedChannels = _selectedChannelsMap[deviceIndex] ?? [];

    return Card(
      elevation: 0,
      color: AppTheme.background,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.borderGrey)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Icon(Iconsax.cpu, color: AppTheme.primaryBlue, size: 20),
            ),
            title: Text(device.name,
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Serial: ${device.serial}  •  Channels: ${device.channelCount}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Auto-fill Channels',
                  child: IconButton(
                    icon: Icon(Iconsax.magic_star, color: AppTheme.primaryBlue, size: 20),
                    onPressed: () => _showAutoFillDialog(deviceIndex),
                  ),
                ),
                IconButton(
                  icon: Icon(Iconsax.trash, color: AppTheme.accentRed, size: 20),
                  onPressed: () => _handleDeleteDevice(deviceIndex),
                ),
              ],
            ),
          ),
          if (device.channelCount > 0)
            const Divider(height: 1, endIndent: 16, indent: 16),
          ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedChannels.length,
            itemBuilder: (context, channelIndex) {
              return isMobile
                  ? _buildChannelDropdown(
                  deviceIndex, channelIndex, selectedChannels)
                  : _buildChannelDropZone(
                  deviceIndex, channelIndex, selectedChannels);
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: (deviceIndex * 100).ms);
  }

  Widget _buildChannelDropZone(
      int deviceIndex, int channelIndex, List<int?> selectedChannels) {
    final int? assignedChannelRecNo = selectedChannels[channelIndex];
    final bool isAssigned = assignedChannelRecNo != null;

    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final bool isHovering = candidateData.isNotEmpty;

        if (isAssigned) {
          final assignedChannel = _allChannels.firstWhere(
                  (c) => c['RecNo'] == assignedChannelRecNo,
              orElse: () => {'ChannelName': 'Unknown', 'ChannelID': ''});

          final String displayLabel = assignedChannel['ChannelID'] != null
              ? "${assignedChannel['ChannelID']} - ${assignedChannel['ChannelName']}"
              : assignedChannel['ChannelName'];

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isHovering ? AppTheme.accentRed.withOpacity(0.1) : AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: isHovering ? Border.all(color: AppTheme.accentRed) : Border.all(color: Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Ch. ${channelIndex + 1}: ', style: TextStyle(color: AppTheme.bodyText, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(displayLabel, style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Iconsax.close_circle, size: 20, color: AppTheme.accentRed),
                  onPressed: () { _handleChannelChange(deviceIndex, channelIndex, null); },
                )
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isHovering ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isHovering ? AppTheme.primaryBlue : AppTheme.borderGrey, width: isHovering ? 2 : 1),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isHovering) Icon(Iconsax.add, color: AppTheme.primaryBlue, size: 16),
                  if (isHovering) SizedBox(width: 8),
                  Text(
                    isHovering ? 'Drop to Assign' : 'Assign to Channel ${channelIndex + 1}',
                    style: TextStyle(color: isHovering ? AppTheme.primaryBlue : AppTheme.bodyText, fontWeight: isHovering ? FontWeight.bold : FontWeight.normal),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      onAccept: (droppedChannelRecNo) {
        _handleChannelChange(deviceIndex, channelIndex, droppedChannelRecNo);
      },
    );
  }

  Widget _buildChannelDropdown(
      int deviceIndex, int channelIndex, List<int?> selectedChannels) {
    final int? currentSelection = selectedChannels[channelIndex];
    List<DropdownMenuItem<int>> items = [];
    items.add(DropdownMenuItem<int>(value: null, child: Text('--- Not Assigned ---', style: TextStyle(color: AppTheme.bodyText))));
    items.addAll(_allChannels.map((channel) {
      final String label = channel['ChannelID'] != null
          ? "${channel['ChannelID']} - ${channel['ChannelName']}"
          : channel['ChannelName'];
      return DropdownMenuItem<int>(value: channel['RecNo'], child: Text(label));
    }));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DropdownButtonFormField<int>(
        value: currentSelection,
        decoration: InputDecoration(
          labelText: 'Device Channel ${channelIndex + 1}',
          prefixIcon: Icon(Iconsax.radar_2, color: AppTheme.primaryBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppTheme.lightGrey.withOpacity(0.5),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: items,
        onChanged: (newValue) {
          _handleChannelChange(deviceIndex, channelIndex, newValue);
        },
      ),
    );
  }

  void _showDeviceFormDialog() {
    final String uniqueSerial = _generateUniqueSerial();
    showDialog(
      context: context,
      builder: (context) {
        return DeviceFormDialog(
          generatedSerial: uniqueSerial,
          onSave: (DeviceData newDevice) {
            _handleAddNewDevice(newDevice);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  String _generateUniqueSerial() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String newSerial;
    do {
      newSerial = String.fromCharCodes(Iterable.generate(
          8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    } while (_addedDevices.any((device) => device.serial == newSerial));
    return newSerial;
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.accentGreen));
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed));
  }
}