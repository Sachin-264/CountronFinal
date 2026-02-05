// [REPLACE] lib/widgets/add_client_dialog.dart

import 'package:countron_app/widgets/successscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:math'; // NAYA
import '../AdminScreens/ClientScreen/Widget/device_form_dialog.dart';
import '../AdminService/client_api_service.dart';
import '../AdminService/image_upload_service.dart';
import '../theme/app_theme.dart';



// Enum baraye username check status
enum VerifyState { none, checking, available, unavailable }

// NAYA: Ek helper class jo locally add kiye gaye devices ko hold karegi
class DeviceData {
  String name;
  String serial;
  int channelCount;
  String location;

  DeviceData({
    required this.name,
    required this.serial,
    required this.channelCount,
    required this.location,
  });
}

class AddClientScreen extends StatefulWidget {
  final Function(String clientName)? onSave;
  const AddClientScreen({super.key, this.onSave});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final ClientApiService _apiService = ClientApiService();
  final ImageUploadService _imageUploadService = ImageUploadService();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  VerifyState _verifyState = VerifyState.none;
  String _usernameError = '';
  bool _isUsernameVerified = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigits = false;

  final PageController _pageController = PageController();

  // Form Keys
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>(); // NAYA: Combined step 3

  // Step 1: Client Info
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _logoPathController = TextEditingController();

  // Step 2: Credentials
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  PlatformFile? _logoFile;
  bool _isUploadingLogo = false;
  Uint8List? _logoBytes;

  // Step 3: Device & Channels
  List<DeviceData> _addedDevices = [];
  int? _createdClientRecNo;
  Map<int, int> _deviceRecNoMap = {};
  bool _channelsLoading = false;
  List<Map<String, dynamic>> _allChannels = [];
  late Map<int, List<int?>> _selectedChannelsMap;
  List<Map<String, dynamic>> _availableChannels = []; // NAYA: For drag/drop

  // NAYA: Updated steps list (3 steps)
  final List<Map<String, dynamic>> _steps = [
    {'title': 'Client Info', 'icon': Iconsax.building_4},
    {'title': 'Credentials', 'icon': Iconsax.shield_security},
    {'title': 'Configure Devices', 'icon': Iconsax.diagram},
  ];

  @override
  void initState() {
    super.initState();
    _selectedChannelsMap = {};
    _usernameController.addListener(() {
      // NAYA: Update helper text state when typing
      setState(() {});
      if (_isUsernameVerified) {
        setState(() {
          _isUsernameVerified = false;
          _verifyState = VerifyState.none;
          _usernameError = '';
        });
      }
    });
    _passwordController.addListener(() {
      final text = _passwordController.text;
      setState(() {
        _hasMinLength = text.length >= 6;
        _hasUppercase = text.contains(RegExp(r'[A-Z]'));
        _hasDigits = text.contains(RegExp(r'[0-9]'));
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _companyNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _logoPathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // === Logo Picker Logic ===
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
    setState(() { _logoFile = file; _isUploadingLogo = true; });
    Uint8List imageBytes;
    if (kIsWeb) { imageBytes = file.bytes!; }
    else { imageBytes = await File(file.path!).readAsBytes(); }
    _logoBytes = imageBytes;
    try {
      final String uniqueFileName = await _imageUploadService.uploadClientLogo(imageBytes, clientName);
      setState(() { _logoPathController.text = uniqueFileName; _isUploadingLogo = false; });
    } catch (e) {
      setState(() { _isUploadingLogo = false; _logoFile = null; _logoBytes = null; });
      _showErrorSnackbar('Logo upload failed: $e');
    }
  }

  // === Username Verification Logic ===
  Future<void> _verifyUsername() async {
    final username = _usernameController.text;
    if (username.isEmpty) {
      setState(() => _usernameError = 'Username is required');
      return;
    }
    setState(() { _isLoading = true; _verifyState = VerifyState.checking; _usernameError = ''; });
    try {
      final bool exists = await _apiService.checkUsernameExists(username);
      if (exists) {
        setState(() { _verifyState = VerifyState.unavailable; _usernameError = 'Taken'; _isUsernameVerified = false; });
      } else {
        setState(() { _verifyState = VerifyState.available; _usernameError = ''; _isUsernameVerified = true; });
      }
    } catch (e) {
      setState(() { _verifyState = VerifyState.none; _usernameError = 'Error'; _isUsernameVerified = false; });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // === NAYA: Updated Step Navigation Logic (3 Steps) ===
  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (_step1FormKey.currentState!.validate()) {
        _goToStep(1);
      }
      return;
    }
    if (_currentStep == 1) { // Moving from Credentials to Devices
      if (_step2FormKey.currentState!.validate()) {
        if (!_hasMinLength || !_hasUppercase || !_hasDigits) {
          _showErrorSnackbar('Please meet all password requirements.');
          return;
        }
        if (!_isUsernameVerified) {
          _showErrorSnackbar('Please verify the username.');
          return;
        }

        // NAYA: Load channels here, BEFORE going to the next step
        setState(() => _isLoading = true);
        await _loadAllChannels();
        setState(() => _isLoading = false);

        _goToStep(2); // Go to the new combined step
      }
      return;
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(step, duration: 300.ms, curve: Curves.easeOut);
  }

  // === NAYA: Updated Finish Setup - Validates new Step 3 ===
  Future<void> _finishSetup() async {
    if (_addedDevices.isEmpty) {
      _showErrorSnackbar('Please add at least one device.');
      return;
    }

    if (_step3FormKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Create Client
        final newClient = await _apiService.createClient(
          adminRecNo: 12,
          username: _usernameController.text,
          passwordHash: _passwordController.text,
          companyName: _companyNameController.text,
          companyAddress: _addressController.text,
          logoPath: _logoPathController.text,
          contactEmail: _emailController.text,
        );
        _createdClientRecNo = newClient['RecNo'];

        // 2. Generate and Register Devices with MMYYxxxx ID
        final now = DateTime.now();
        String month = now.month.toString().padLeft(2, '0');
        String year = now.year.toString().substring(2);

        for (int i = 0; i < _addedDevices.length; i++) {
          DeviceData device = _addedDevices[i];

          // Fetch the next global sequence number (xxxx)
          final int nextIdValue = await _apiService.getNextDeviceRecNo();
          String paddedId = nextIdValue.toString().padLeft(4, '0');

          // Combine to MMYYxxxx (e.g., 02260001)
          int generatedRecNo = int.parse('$month$year$paddedId');

          final newDevice = await _apiService.registerDevice(
            recNo: generatedRecNo, // Pass the generated ID
            clientRecNo: _createdClientRecNo!,
            deviceName: device.name,
            serialNumber: device.serial,
            channelsCount: device.channelCount,
            location: device.location,
          );
          _deviceRecNoMap[i] = newDevice['RecNo'];
        }

        // 3. Assign Channels
        for (int deviceIndex in _selectedChannelsMap.keys) {
          int deviceRecNo = _deviceRecNoMap[deviceIndex]!;
          List<int?> channels = _selectedChannelsMap[deviceIndex]!;

          for (int cIndex = 0; cIndex < channels.length; cIndex++) {
            final channelRecNo = channels[cIndex];
            if (channelRecNo != null) {
              await _apiService.assignChannelToDevice(
                deviceRecNo: deviceRecNo,
                channelRecNo: channelRecNo,
                channelIndex: cIndex + 1,
              );
            }
          }
        }

        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => SuccessScreen(
            message: "Client '${_companyNameController.text}' setup complete!",
          ),
        ));

        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            widget.onSave?.call(_companyNameController.text);
            Navigator.pop(context);
          }
        });

      } catch (e) {
        _showErrorSnackbar('Failed to finish setup: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  // NAYA: Updated to populate both channel lists
  Future<void> _loadAllChannels() async {
    setState(() => _channelsLoading = true);
    try {
      _allChannels = await _apiService.getAllChannels();
      // NAYA: Available channels is now just the full list
      _availableChannels = List.from(_allChannels);
    } catch (e) {
      _showErrorSnackbar('Failed to load channels: $e');
    }
    setState(() => _channelsLoading = false);
  }


  // === NAYA: Device Form Dialog ko Dikhayein ===
  void _showDeviceFormDialog() {
    // NAYA: Autogenerate serial number
    final String uniqueSerial = _generateUniqueSerial();

    showDialog(
      context: context,
      builder: (context) {
        return DeviceFormDialog( // NAYA: Use the imported dialog
          // NAYA: Pass the generated serial to the dialog
          generatedSerial: uniqueSerial,
          onSave: (DeviceData newDevice) {
            setState(() {
              // NAYA: Add new device to the top of the list
              _addedDevices.insert(0, newDevice);

              // NAYA: Re-key the channel map to add new device at index 0
              final newMap = <int, List<int?>>{};
              // Shift all existing entries down by 1
              for (int i = 0; i < _addedDevices.length - 1; i++) {
                newMap[i + 1] = _selectedChannelsMap[i] ?? [];
              }
              // Add the new device at index 0
              newMap[0] = List<int?>.filled(newDevice.channelCount, null);
              _selectedChannelsMap = newMap;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  // NAYA: Helper to generate a unique serial
  String _generateUniqueSerial() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String newSerial;
    do {
      newSerial = String.fromCharCodes(Iterable.generate(
          8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      // Ensure it's unique among devices already added
    } while (_addedDevices.any((device) => device.serial == newSerial));
    return newSerial;
  }

  // NAYA: Add this helper function to un-assign a single channel
  void _unassignChannel(int deviceIndex, int channelIndex, int channelRecNo) {
    // Find the channel data from the master list
    final channelData = _allChannels.firstWhere(
          (c) => c['RecNo'] == channelRecNo,
      orElse: () => <String, dynamic>{}, // Return an empty map
    );

    // Check if the map is not empty
    if (channelData.isNotEmpty) {
      setState(() {
        // 1. Set the slot back to null
        _selectedChannelsMap[deviceIndex]![channelIndex] = null;
        // 2. NAYA: No longer need to add channel back to available pool
      });
    }
  }

  // NAYA: Add this to return ALL channels from a deleted device
  void _returnChannelsToPool(int deviceIndex) {
    // NAYA: This function is now only responsible for logging or other cleanup.
    // We no longer need to modify the _availableChannels list.
    final assignedChannels = _selectedChannelsMap[deviceIndex];
    if (assignedChannels == null) return;
    // (We can leave this function empty or remove it if it has no other purpose)
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // NAYA: Responsive check is now based on a wider breakpoint for better layout
    final isMobile = MediaQuery.of(context).size.width < 700;

    double progress = (_currentStep + 1) / _steps.length; // Auto-updates to 3 steps
    String progressPercent = "${(progress * 100).toInt()}%";

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'CREATE NEW CLIENT',
          style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.darkText),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, color: AppTheme.bodyText),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8.0),
          child: Stack(
            children: [
              Container(height: 6.0, width: double.infinity, decoration: BoxDecoration(color: AppTheme.borderGrey)),
              AnimatedContainer(
                duration: 300.ms,
                height: 6.0,
                width: MediaQuery.of(context).size.width * progress,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 12,
                child: Text(
                  progressPercent,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildStepIndicator(isMobile),
              const SizedBox(height: 24),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStepForm(_step1FormKey, _buildClientInfoStep()),
                    _buildStepForm(_step2FormKey, _buildCredentialsStep()),
                    // NAYA: Call the new combined step builder
                    _buildStepForm(_step3FormKey, _buildDeviceAndChannelStep(isMobile)),
                  ],
                ),
              ),

              _buildNavigationButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  // === NAYA: Helper: Step Indicator (Top) with Color Logic ===
  Widget _buildStepIndicator(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_steps.length, (index) {
          final bool isActive = _currentStep >= index;
          final bool isCurrent = _currentStep == index;
          // NAYA: Color logic for completed steps
          final bool isCompleted = isActive && !isCurrent;
          final color = isCurrent ? AppTheme.primaryBlue : (isCompleted ? AppTheme.accentGreen : AppTheme.borderGrey);

          return Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: isCurrent ? 18 : 14,
                  backgroundColor: color, // Updated color
                  // NAYA: Updated icon color for inactive state
                  child: Icon(
                    _steps[index]['icon'],
                    color: isActive ? Colors.white : AppTheme.bodyText,
                    size: isCurrent ? 18 : 16,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(
                    _steps[index]['title'],
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? AppTheme.darkText : AppTheme.bodyText,
                    ),
                  )
                ],
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: color, // Updated color
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // Helper: Wrapper for form pages
  Widget _buildStepForm(Key key, Widget child) {
    return Form(
      key: key,
      child: child,
    );
  }

  // Helper: Navigation Buttons (Bottom)
  Widget _buildNavigationButtons(ThemeData theme) {
    // NAYA: The last step is now index 2
    bool isLastStep = _currentStep == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.borderGrey)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedOpacity(
            opacity: _currentStep > 0 ? 1.0 : 0.0,
            duration: 200.ms,
            child: TextButton.icon(
              onPressed: (_isLoading || _currentStep == 0) ? null : _previousStep,
              icon: const Icon(Iconsax.arrow_left_2, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.bodyText,
              ),
            ),
          ),

          ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : (isLastStep ? _finishSetup : _nextStep),
            icon: _isLoading
                ? Container(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(isLastStep ? Iconsax.check : Iconsax.arrow_right_3, size: 20),
            label: Text(
              isLastStep ? 'Finish Setup' : 'Continue',
              style: AppTheme.buttonText.copyWith(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastStep ? AppTheme.accentGreen : AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === Step 1: Client Info ===
  Widget _buildClientInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
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
          const SizedBox(height: 16),
          _buildTextFormField(
            controller: _addressController,
            label: 'Company Address',
            icon: Iconsax.location,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildLogoPicker(),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // === Step 2: Credentials ===
  Widget _buildCredentialsStep() {
    // NAYA: Show helper text if user has typed but not verified
    final bool showVerifyHelper = _verifyState == VerifyState.none &&
        _usernameController.text.isNotEmpty;

    // NAYA: Conditionally apply animation
    Widget verifyButton = _buildVerifyButton();
    if (showVerifyHelper) {
      // We apply the animation to the button widget
      // and make it repeat to create a "pulse"
      verifyButton = verifyButton.animate(
        // Make the animation repeat
        onPlay: (controller) => controller.repeat(reverse: true),
      ).scaleXY(
        end: 1.1, // Scale up to 110%
        duration: 1000.ms,
        curve: Curves.easeInOut,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _usernameController,
                  label: 'Client Username *',
                  icon: Iconsax.user,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!_isUsernameVerified) return 'Please verify username';
                    if (_verifyState == VerifyState.unavailable) return 'Username taken';
                    return null;
                  },
                  errorText: _usernameError.isNotEmpty ? _usernameError : null,
                  // NAYA: Helper text to guide user
                  helperText: showVerifyHelper ? "Click 'Verify' to continue" : null,
                ),
              ),
              const SizedBox(width: 12),
              // NAYA: Use the conditionally animated button
              verifyButton,
            ],
          ),
          const SizedBox(height: 24),
          _buildTextFormField(
            controller: _passwordController,
            label: 'Client Password *',
            icon: Iconsax.key,
            isPassword: _obscurePassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!_hasMinLength || !_hasUppercase || !_hasDigits) {
                return 'Must meet all requirements';
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Iconsax.eye_slash : Iconsax.eye, color: AppTheme.bodyText),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildPasswordRequirement(label: 'At least 6 characters', isMet: _hasMinLength),
          _buildPasswordRequirement(label: 'At least one uppercase (A-Z)', isMet: _hasUppercase),
          _buildPasswordRequirement(label: 'At least one number (0-9)', isMet: _hasDigits),
          const SizedBox(height: 24),
          _buildTextFormField(
            controller: _confirmPasswordController,
            label: 'Confirm Password *',
            icon: Iconsax.key,
            isPassword: _obscureConfirmPassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye, color: AppTheme.bodyText),
              onPressed: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }


  // === NAYA: The new combined Step 3 (replaces old Step 3 & 4) ===
  Widget _buildDeviceAndChannelStep(bool isMobile) {
    Widget availableChannelsPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.lightGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGrey)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // NAYA: List now shows count of all channels
              'Available Channels (${_allChannels.length})',
              style: Theme.of(context).textTheme.titleMedium
          ),
          const SizedBox(height: 12),
          if (_channelsLoading)
            const Center(child: CircularProgressIndicator()),
          if (_allChannels.isEmpty && !_channelsLoading) // NAYA: Check _allChannels
            const Center(child: Text('No channels available.')),

          // Use Wrap for a modern chip-like layout
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            // NAYA: Build from _allChannels
            children: _allChannels
                .map((channel) => _buildDraggableChannel(channel))
                .toList(),
          ),
        ],
      ),
    );

    Widget assignedDevicesPanel = Column(
      children: [
        ElevatedButton.icon(
          onPressed: _showDeviceFormDialog, // This logic stays the same!
          icon: const Icon(Iconsax.add),
          label: const Text('Add New Device'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
            'Assigned Devices (${_addedDevices.length})',
            style: Theme.of(context).textTheme.titleMedium
        ),
        const SizedBox(height: 16),

        if (_addedDevices.isEmpty)
          Center(child: Text('Add a device to begin.', style: TextStyle(color: AppTheme.bodyText))),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _addedDevices.length,
          itemBuilder: (context, deviceIndex) {
            final device = _addedDevices[deviceIndex];
            // NAYA: Pass isMobile flag to the card builder
            return _buildDeviceCard(device, deviceIndex, isMobile);
          },
        ),
      ],
    );

    // Return a responsive layout
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: isMobile
          ? Column( // Vertical stack on mobile
        children: [
          assignedDevicesPanel, // Devices first on mobile
        ],
      )
          : Row( // Side-by-side on desktop
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: availableChannelsPanel, // Show available channels for drag-drop
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: assignedDevicesPanel,
          ),
        ],
      ),
    );
  }

  // NAYA: A widget for the draggable channel chip
  Widget _buildDraggableChannel(Map<String, dynamic> channel) {
    final int channelRecNo = channel['RecNo'];
    final String channelName = channel['ChannelName'] ?? 'Unnamed';

    // NAYA: Check if this channel is assigned to *any* slot on *any* device
    bool isAssignedAnywhere = false;
    for (var assignedList in _selectedChannelsMap.values) {
      if (assignedList.contains(channelRecNo)) {
        isAssignedAnywhere = true;
        break;
      }
    }

    // The 'data' is what we pass to the DragTarget
    return Draggable<int>(
      data: channelRecNo,
      feedback: Material(
        color: Colors.transparent,
        child: Chip(
          label: Text(channelName),
          padding: const EdgeInsets.all(12),
          backgroundColor: AppTheme.background,
          elevation: 3.0,
          side: BorderSide.none,
        ).animate().scaleXY(begin: 1.0, end: 1.1),
      ),
      // What's left behind in the list
      childWhenDragging: Chip(
        label: Text(channelName),
        backgroundColor: AppTheme.borderGrey,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.5)),
        side: BorderSide.none,
      ),
      // The chip in its normal state
      child: Chip(
        label: Text(channelName, style: TextStyle(
            fontWeight: FontWeight.w500,
            // NAYA: Grey out text if assigned
            color: isAssignedAnywhere ? AppTheme.bodyText.withOpacity(0.6) : AppTheme.darkText
        )),
        avatar: Icon(Iconsax.radar_2, size: 16,
            // NAYA: Grey out icon if assigned
            color: isAssignedAnywhere ? AppTheme.bodyText.withOpacity(0.6) : AppTheme.primaryBlue
        ),
        backgroundColor: AppTheme.background,
        side: BorderSide(color: AppTheme.borderGrey),
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  // NAYA: A card for the device, handles BOTH mobile and desktop
  Widget _buildDeviceCard(DeviceData device, int deviceIndex, bool isMobile) {
    return Card(
      elevation: 0,
      color: AppTheme.background,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.borderGrey)
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Icon(Iconsax.cpu, color: AppTheme.primaryBlue, size: 20),
            ),
            title: Text(device.name, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Serial: ${device.serial}  •  Channels: ${device.channelCount}'),
            trailing: IconButton(
              icon: Icon(Iconsax.trash, color: AppTheme.accentRed, size: 20),
              onPressed: () {
                // NAYA: Corrected delete logic
                setState(() {
                  // 1. Return all assigned channels to the pool
                  _returnChannelsToPool(deviceIndex);

                  // 2. Remove the device
                  _addedDevices.removeAt(deviceIndex);

                  // 3. Remove the map entry for this device
                  _selectedChannelsMap.remove(deviceIndex);

                  // 4. Re-key the map for all subsequent devices
                  final updatedMap = <int, List<int?>>{};
                  // NAYA: Corrected re-keying logic (rewritten for clarity)
                  // Get all the keys and sort them
                  final sortedKeys = _selectedChannelsMap.keys.toList();
                  sortedKeys.sort();

                  int newKey = 0;
                  // Use a standard for-in loop which is much cleaner
                  for (final oldKey in sortedKeys) {
                    if (oldKey != deviceIndex) {
                      updatedMap[newKey] = _selectedChannelsMap[oldKey]!;
                      newKey++;
                    }
                  }

                  _selectedChannelsMap = updatedMap; // Assign the new map
                });
              },
            ),
          ),
          if (device.channelCount > 0)
            const Divider(height: 1, endIndent: 16, indent: 16),

          // NAYA: Responsive channel assignment UI
          ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: device.channelCount,
            itemBuilder: (context, channelIndex) {
              // Show Dropdowns for mobile, Drag Targets for desktop
              return isMobile
                  ? _buildChannelDropdown(deviceIndex, channelIndex)
                  : _buildChannelDropZone(deviceIndex, channelIndex);
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: (deviceIndex * 100).ms);
  }

  // NAYA: The drop zone for a single channel slot (DESKTOP)
  Widget _buildChannelDropZone(int deviceIndex, int channelIndex) {
    // Check if a channel is already assigned here
    final int? assignedChannelRecNo = _selectedChannelsMap[deviceIndex]![channelIndex];
    final bool isAssigned = assignedChannelRecNo != null;

    return DragTarget<int>(
      // This builder shows the UI
      builder: (context, candidateData, rejectedData) {
        if (isAssigned) {
          // Find the channel name from the main list
          final assignedChannel = _allChannels.firstWhere(
                  (c) => c['RecNo'] == assignedChannelRecNo,
              orElse: () => {'ChannelName': 'Error'}
          );
          // Show the assigned chip
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Ch. ${channelIndex + 1}: ${assignedChannel['ChannelName']}',
                    style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Iconsax.close_circle, size: 20, color: AppTheme.accentRed),
                  onPressed: () {
                    // Un-assign logic
                    _unassignChannel(deviceIndex, channelIndex, assignedChannelRecNo);
                  },
                )
              ],
            ),
          );
        }

        // Show the empty drop zone
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? AppTheme.primaryBlue.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: candidateData.isNotEmpty
                    ? AppTheme.primaryBlue
                    : AppTheme.borderGrey,
                width: candidateData.isNotEmpty ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                'Assign to Channel ${channelIndex + 1}',
                style: TextStyle(color: AppTheme.bodyText),
              ),
            ),
          ),
        );
      },
      // This logic runs when a channel is dropped
      onAccept: (droppedChannelRecNo) {
        // Check if this channel is already assigned somewhere else on THIS device
        if (_selectedChannelsMap[deviceIndex]!.contains(droppedChannelRecNo)) {
          _showErrorSnackbar('Channel is already assigned to this device.');
          return;
        }

        setState(() {
          // 1. Assign it in the map
          _selectedChannelsMap[deviceIndex]![channelIndex] = droppedChannelRecNo;
          // 2. NAYA: No longer need to remove from available list
        });
      },
    );
  }

  // NAYA: The dropdown for a single channel slot (MOBILE)
  Widget _buildChannelDropdown(int deviceIndex, int channelIndex) {
    final int? currentSelection = _selectedChannelsMap[deviceIndex]![channelIndex];

    // Build the list of available items for this dropdown
    List<DropdownMenuItem<int>> items = [];

    // 1. Add the "Not Assigned" option
    items.add(
      DropdownMenuItem<int>(
        value: null,
        child: Text('--- Not Assigned ---', style: TextStyle(color: AppTheme.bodyText)),
      ),
    );

    // 2. NAYA: Add ALL channels from the master list
    items.addAll(_allChannels.map((channel) {
      return DropdownMenuItem<int>(
        value: channel['RecNo'],
        child: Text(channel['ChannelName'] ?? 'Unnamed Channel'),
      );
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
        // NAYA: Updated onChanged logic
        onChanged: (newValue) {
          // Check for conflict on THIS device
          final otherSelections = List.from(_selectedChannelsMap[deviceIndex]!);
          otherSelections.removeAt(channelIndex); // Don't check against its own slot
          if (newValue != null && otherSelections.contains(newValue)) {
            _showErrorSnackbar('Channel is already assigned to this device.');
            // Don't update state, which reverts the dropdown
            setState(() {});
            return;
          }

          setState(() {
            // Just update the map. Don't touch _availableChannels.
            _selectedChannelsMap[deviceIndex]![channelIndex] = newValue;
          });
        },
      ),
    );
  }

  // === NAYA: Logo Picker UI (DottedBorder removed) ===
  Widget _buildLogoPicker() {
    return InkWell(
      onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.lightGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.bodyText.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: _buildLogoPickerContent(),
      ),
    );
  }

  Widget _buildLogoPickerContent() {
    if (_isUploadingLogo) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Uploading...', style: Theme.of(context).textTheme.bodyMedium)
        ],
      ));
    }

    if (_logoBytes != null || (_logoFile != null && _logoFile!.path != null)) {
      ImageProvider imageProvider;
      if (kIsWeb && _logoBytes != null) {
        imageProvider = MemoryImage(_logoBytes!);
      } else {
        imageProvider = FileImage(File(_logoFile!.path!));
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Center(child: Text('Error loading image')),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: ElevatedButton.icon(
              onPressed: _pickAndUploadLogo,
              icon: const Icon(Iconsax.edit, size: 16),
              label: const Text('Change'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.background.withOpacity(0.8),
                foregroundColor: AppTheme.darkText,
              ),
            ),
          )
        ],
      );
    }

    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Iconsax.image, color: AppTheme.bodyText, size: 40),
        const SizedBox(height: 16),
        Text('Upload Client Logo', style: Theme.of(context).textTheme.titleMedium),
        Text('(Optional)', style: Theme.of(context).textTheme.bodySmall),
      ],
    ));
  }

  // Helper: Verify Button
  Widget _buildVerifyButton() {
    Widget child;
    Color color = AppTheme.accentPurple;
    String tooltip = 'Check username availability';

    switch (_verifyState) {
      case VerifyState.checking:
        child = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
        tooltip = 'Checking...';
        break;
      case VerifyState.available:
        child = const Icon(Iconsax.check, color: Colors.white);
        color = AppTheme.accentGreen;
        tooltip = 'Username is available!';
        break;
      case VerifyState.unavailable:
        child = const Icon(Iconsax.close_circle, color: Colors.white);
        color = AppTheme.accentRed;
        tooltip = 'Username is taken';
        break;
      case VerifyState.none:
      default:
        child = const Icon(Iconsax.verify, color: Colors.white);
        color = AppTheme.accentPurple;
    }

    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyUsername,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          minimumSize: const Size(60, 58),
        ),
        child: child,
      ),
    );
  }

  // NAYA: Password Requirement Helper
  Widget _buildPasswordRequirement({required String label, required bool isMet}) {
    final color = isMet ? AppTheme.accentGreen : AppTheme.bodyText.withOpacity(0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: 300.ms,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isMet ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: isMet
                ? Icon(Iconsax.check, color: color, size: 12)
                : SizedBox(),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Text Field
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isPassword = false,
    int maxLines = 1,
    Widget? suffixIcon,
    String? helperText,
    String? errorText,
    bool readOnly = false, // NAYA
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: isPassword,
      maxLines: maxLines,
      readOnly: readOnly, // NAYA
      style: TextStyle(
          color: readOnly ? AppTheme.bodyText : AppTheme.darkText, // NAYA
          fontWeight: FontWeight.w500
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        suffixIcon: suffixIcon,
        helperText: helperText,
        errorText: errorText,
        // NAYA: Style helper text to match guide
        helperStyle: TextStyle(color: AppTheme.primaryBlue.withOpacity(0.9), fontWeight: FontWeight.w500),
        errorStyle: TextStyle(color: AppTheme.accentRed),
        filled: true,
        fillColor: readOnly ? AppTheme.lightGrey : AppTheme.background, // NAYA
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentRed, width: 2),
        ),
      ),
    );
  }
}

// === NAYA: _DeviceFormDialog has been moved to its own file ===
// See lib/widgets/device_form_dialog.dart