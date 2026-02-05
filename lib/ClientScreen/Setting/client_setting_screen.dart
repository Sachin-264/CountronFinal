import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for TextInputFormatter
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../AdminService/image_upload_service.dart';
import '../../AdminService/client_api_service.dart'; // NEW IMPORT
import '../../ClinetService/setting_api_service.dart';
import '../../provider/client_provider.dart';
import '../../theme/client_theme.dart';

class ClientSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ClientSettingsScreen({super.key, required this.userData});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final SettingsApiService _settingsService = SettingsApiService();
  final ClientApiService _clientApiService = ClientApiService(); // New Instance
  final ImageUploadService _imageUploadService = ImageUploadService();

  final _reportCompanyController = TextEditingController();
  final _reportAddressController = TextEditingController();

  final _emailInputController = TextEditingController();
  final _alarmDelayController = TextEditingController(text: "0");

  // NEW: Controller for Channel Limit
  final _channelLimitController = TextEditingController();

  List<String> _emailList = [];
  String _selectedFrequency = 'Immediate';
  bool _isAlarmEnabled = true;
  bool _isLoading = false;
  bool _isUploadingLogo = false;
  bool _isSavingAlarm = false;
  bool _isSavingFreq = false;
  bool _isSavingLimit = false; // New loading state

  String? _currentReportLogoPath;
  Uint8List? _reportLogoBytes;

  static const String _imageBaseUrl = "https://storage.googleapis.com/upload-images-34/images/LMS/";

  final List<String> _freqOptions = ['30 sec', '1min', '5min', '10min', '15mins', '20mins', '30mins', '1hr'];
  String? _selectedSFreq;
  String? _selectedTFreq;

  @override
  void initState() {
    super.initState();
    _fetchDeviceSettings();
    _fetchAlarmSettings();
    _fetchFrequencySettings();
    _fetchChannelLimit(); // Fetch the limit on init
  }

  @override
  void dispose() {
    _reportCompanyController.dispose();
    _reportAddressController.dispose();
    _emailInputController.dispose();
    _alarmDelayController.dispose();
    _channelLimitController.dispose(); // Dispose new controller
    super.dispose();
  }

  String _getApiBaseUrl(String endpoint) {
    return 'ApiConstants.baseUrl$endpoint';
  }

  Future<void> _fetchDeviceSettings() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;
    setState(() => _isLoading = true);
    final data = await _settingsService.fetchSettings(provider.selectedDeviceRecNo!);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _reportCompanyController.text = data['ClientCompanyName'] ?? '';
          _reportAddressController.text = data['ClientAddress'] ?? '';
          _currentReportLogoPath = data['Logo'];
        }
      });
    }
  }

  Future<void> _saveDeviceSettings() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;
    setState(() => _isLoading = true);
    final success = await _settingsService.saveSettings(
      recNo: provider.selectedDeviceRecNo!,
      companyName: _reportCompanyController.text,
      address: _reportAddressController.text,
      logoPath: _currentReportLogoPath ?? '',
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) _showSuccessSnackbar("Branding saved!");
      else _showErrorSnackbar("Failed to save branding.");
    }
  }

  // === NEW: Fetch Channel Limit ===
  Future<void> _fetchChannelLimit() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;

    try {
      final limit = await _clientApiService.getDeviceChannelLimit(provider.selectedDeviceRecNo!);
      if (mounted) {
        setState(() {
          _channelLimitController.text = limit.toString();
        });
      }
    } catch (e) {
      // Handle error silently or show snackbar
      print("Error fetching limit: $e");
    }
  }

  // === NEW: Save Channel Limit ===
  Future<void> _saveChannelLimit() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;

    // 1. Get Hardware Max Limit
    final int hardwareMax = provider.selectedDeviceData?['ChannelsCount'] ?? 0;

    // 2. Get User Input
    final int inputLimit = int.tryParse(_channelLimitController.text) ?? 0;

    // 3. Validation Logic
    if (inputLimit < 0) {
      _showErrorSnackbar("Limit cannot be negative.");
      return;
    }

    if (inputLimit > hardwareMax) {
      _showErrorSnackbar("Limit cannot exceed device capacity ($hardwareMax).");
      // Reset to max to help user
      setState(() {
        _channelLimitController.text = hardwareMax.toString();
      });
      return;
    }

    setState(() => _isSavingLimit = true);

    try {
      final success = await _clientApiService.updateDeviceChannelLimit(
        recNo: provider.selectedDeviceRecNo!,
        limit: inputLimit,
      );

      if (mounted) {
        setState(() => _isSavingLimit = false);
        if (success) {
          _showSuccessSnackbar("Channel limit updated!");
        } else {
          _showErrorSnackbar("Failed to update limit.");
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSavingLimit = false);
      _showErrorSnackbar("Error: $e");
    }
  }

  Future<void> _fetchAlarmSettings() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;

    final data = await _settingsService.fetchAlarmSettings(provider.selectedDeviceRecNo!);
    if (mounted && data != null) {
      setState(() {
        String rawEmails = data['AlarmEmails'] ?? '';
        if (rawEmails.isNotEmpty) {
          _emailList = rawEmails.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else {
          _emailList = [];
        }

        _selectedFrequency = data['AlertFrequency'] ?? 'Immediate';
        _alarmDelayController.text = (data['AlertDelayMinutes'] ?? 0).toString();
        _isAlarmEnabled = (data['IsEnabled'] == 1 || data['IsEnabled'] == true);
      });
    }
  }

  Future<void> _saveAlarmSettings() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;

    setState(() => _isSavingAlarm = true);

    String joinedEmails = _emailList.join(',');

    final success = await _settingsService.saveAlarmSettings(
      recNo: provider.selectedDeviceRecNo!,
      emails: joinedEmails,
      frequency: _selectedFrequency,
      delayMinutes: int.tryParse(_alarmDelayController.text) ?? 0,
      isEnabled: _isAlarmEnabled,
    );

    if (mounted) {
      setState(() => _isSavingAlarm = false);
      if (success) _showSuccessSnackbar("Alarm settings saved!");
      else _showErrorSnackbar("Failed to save alarm settings.");
    }
  }

  Future<void> _fetchFrequencySettings() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;
    final data = await _settingsService.fetchFrequencySettings(provider.selectedDeviceRecNo!);
    if (mounted && data != null) {
      setState(() {
        String? sFreq = data['SFreq'];
        _selectedSFreq = _freqOptions.contains(sFreq) ? sFreq : _freqOptions.first;
        String? tFreq = data['TFreq'];
        _selectedTFreq = _freqOptions.contains(tFreq) ? tFreq : _freqOptions.first;
      });
    }
  }

  Future<void> _saveFrequencySettings() async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    if (provider.selectedDeviceRecNo == null) return;
    setState(() => _isSavingFreq = true);
    final success = await _settingsService.saveFrequencySettings(
      recNo: provider.selectedDeviceRecNo!,
      sFreq: _selectedSFreq ?? _freqOptions.first,
      tFreq: _selectedTFreq ?? _freqOptions.first,
    );
    if (mounted) {
      setState(() => _isSavingFreq = false);
      if (success) _showSuccessSnackbar("Frequency settings saved!");
      else _showErrorSnackbar("Failed to save frequency settings.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientProvider>(
      builder: (context, provider, child) {
        final userData = provider.clientData ?? widget.userData;
        final hasDevice = provider.selectedDeviceRecNo != null;

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 900;

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 320, child: _buildProfileCard(userData)),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          if (hasDevice) ...[
                            _buildBrandingCard(isDesktop: true),
                            const SizedBox(height: 24),
                            // NEW: Channel Limit Card
                            _buildChannelLimitCard(isDesktop: true, provider: provider),
                            const SizedBox(height: 24),
                            _buildAlarmCard(isDesktop: true),
                            const SizedBox(height: 24),
                            _buildFrequencyCard(isDesktop: true),
                          ] else
                            _buildNoDevicePlaceholder(),
                        ],
                      ),
                    )
                  ],
                ),
              );
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileCard(userData),
                    const SizedBox(height: 20),
                    if (hasDevice) ...[
                      _buildBrandingCard(isDesktop: false),
                      const SizedBox(height: 20),
                      // NEW: Channel Limit Card
                      _buildChannelLimitCard(isDesktop: false, provider: provider),
                      const SizedBox(height: 20),
                      _buildAlarmCard(isDesktop: false),
                      const SizedBox(height: 20),
                      _buildFrequencyCard(isDesktop: false),
                    ] else
                      _buildNoDevicePlaceholder(),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    final String? logoPath = data['LogoPath'];
    final imageProvider = (logoPath != null && logoPath.isNotEmpty)
        ? NetworkImage("$_imageBaseUrl$logoPath")
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ClientTheme.textDark)),
              InkWell(
                onTap: _showEditProfileDialog,
                child: Icon(Iconsax.edit_2, size: 18, color: ClientTheme.primaryColor),
              )
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ClientTheme.background,
              border: Border.all(color: Colors.grey.shade200, width: 3),
              image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
            ),
            child: imageProvider == null ? Icon(Iconsax.user, size: 40, color: ClientTheme.textLight) : null,
          ),
          const SizedBox(height: 16),
          Text(data['DisplayName'] ?? "Client Name",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(data['ContactEmail'] ?? "", style: TextStyle(color: ClientTheme.textLight, fontSize: 13)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          _buildProfileRow(Iconsax.user, "Username", data['Username']),
          const SizedBox(height: 12),
          InkWell(
            onTap: _triggerResetPassword,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.lock, size: 16, color: ClientTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text("Reset Password", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientTheme.primaryColor)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildBrandingCard({required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.printer, color: ClientTheme.primaryColor),
              const SizedBox(width: 10),
              Text("Report Branding", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ClientTheme.textDark)),
              const Spacer(),
              if (isDesktop) _buildSaveButton(_isLoading, _saveDeviceSettings, "Save Branding"),
            ],
          ),
          const SizedBox(height: 24),

          isDesktop
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoUploader(),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildCompactField("Company Name", _reportCompanyController, Iconsax.building)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCompactField("Address", _reportAddressController, Iconsax.location)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text("Details appear on PDF headers.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            ],
          )
              : Column(
            children: [
              Center(child: _buildLogoUploader()),
              const SizedBox(height: 20),
              _buildCompactField("Company Name", _reportCompanyController, Iconsax.building),
              const SizedBox(height: 12),
              _buildCompactField("Address", _reportAddressController, Iconsax.location),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: _buildSaveButton(_isLoading, _saveDeviceSettings, "Save"))
            ],
          )
        ],
      ),
    );
  }

  // === NEW: Channel Limit Widget ===
  Widget _buildChannelLimitCard({required bool isDesktop, required ClientProvider provider}) {
    final int maxChannels = provider.selectedDeviceData?['ChannelsCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.slider_horizontal, color: ClientTheme.primaryColor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Channel Access Limit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ClientTheme.textDark)),
                  if(isDesktop) Text("Restrict visible channels (Max: $maxChannels)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              if (isDesktop) _buildSaveButton(_isSavingLimit, _saveChannelLimit, "Update Limit"),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Set Limit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 45,
                      child: TextField(
                        controller: _channelLimitController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                            hintText: "Enter limit (0 - $maxChannels)",
                            prefixIcon: const Icon(Iconsax.sort, size: 16, color: Colors.grey),
                            suffixText: "/ $maxChannels",
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ClientTheme.primaryColor)),
                            filled: true,
                            fillColor: Colors.grey.shade50
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Enter 0 or leave empty to allow all $maxChannels channels.",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              if (isDesktop) const Spacer(flex: 2), // Spacing for desktop layout
            ],
          ),

          if (!isDesktop) ...[
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: _buildSaveButton(_isSavingLimit, _saveChannelLimit, "Update Limit"))
          ]
        ],
      ),
    );
  }

  Widget _buildAlarmCard({required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.notification_bing, color: _isAlarmEnabled ? ClientTheme.primaryColor : Colors.grey),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Alarm Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ClientTheme.textDark)),
                  if(isDesktop) Text("Send emails when thresholds are crossed.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isAlarmEnabled,
                  activeColor: ClientTheme.primaryColor,
                  onChanged: (val) => setState(() => _isAlarmEnabled = val),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 16),
                _buildSaveButton(_isSavingAlarm, _saveAlarmSettings, "Update Alarms"),
              ]
            ],
          ),

          if (_isAlarmEnabled) ...[
            const SizedBox(height: 24),
            _buildEmailAdderSection(),
            const SizedBox(height: 16),

            isDesktop
                ? Row(
              children: [
                Expanded(child: _buildDropdownField()),
                const SizedBox(width: 16),
                Expanded(child: _buildCompactField("Delay (mins)", _alarmDelayController, Iconsax.timer_1)),
              ],
            )
                : Row(
              children: [
                Expanded(flex: 3, child: _buildDropdownField()),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildCompactField("Delay", _alarmDelayController, Iconsax.timer_1)),
              ],
            ),

            if (!isDesktop) ...[
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: _buildSaveButton(_isSavingAlarm, _saveAlarmSettings, "Update Alarms"))
            ]
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text("Alarms are currently disabled for this device.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFrequencyCard({required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.setting, color: ClientTheme.primaryColor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Device Frequency", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ClientTheme.textDark)),
                  if(isDesktop) Text("Set update frequencies for sensors.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              if (isDesktop) _buildSaveButton(_isSavingFreq, _saveFrequencySettings, "Update Frequency"),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildFreqDropdown("Saving Frequency", _selectedSFreq, (v) => setState(() => _selectedSFreq = v), Iconsax.timer_start)),
              const SizedBox(width: 16),
              Expanded(child: _buildFreqDropdown("Transmitting Frequency", _selectedTFreq, (v) => setState(() => _selectedTFreq = v), Iconsax.timer_pause)),
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: _buildSaveButton(_isSavingFreq, _saveFrequencySettings, "Update Frequency"))
          ]
        ],
      ),
    );
  }

  Widget _buildEmailAdderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recipient Emails", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 45,
                child: TextField(
                  controller: _emailInputController,
                  decoration: InputDecoration(
                    hintText: "Enter email address",
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Iconsax.sms, size: 16, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  onSubmitted: (_) => _handleAddEmail(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _handleAddEmail,
              icon: const Icon(Iconsax.add_circle, color: Colors.blue),
              tooltip: "Add Email",
            )
          ],
        ),
        const SizedBox(height: 10),
        if (_emailList.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _emailList.map((email) {
              return Chip(
                label: Text(email, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.withOpacity(0.1),
                side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.blue),
                onDeleted: () {
                  setState(() {
                    _emailList.remove(email);
                  });
                },
              );
            }).toList(),
          )
        else
          const Text("No emails added.", style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  void _handleAddEmail() {
    String val = _emailInputController.text.trim();
    if (val.isNotEmpty && val.contains('@')) {
      if (!_emailList.contains(val)) {
        setState(() {
          _emailList.add(val);
          _emailInputController.clear();
        });
      } else {
        _showErrorSnackbar("Email already exists");
      }
    } else if (val.isNotEmpty) {
      _showErrorSnackbar("Invalid email format");
    }
  }

  Widget _buildLogoUploader() {
    return GestureDetector(
      onTap: _isUploadingLogo ? null : _pickAndUploadReportLogo,
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ClientTheme.background, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
              image: _getReportImageProvider() != null ? DecorationImage(image: _getReportImageProvider()!, fit: BoxFit.cover) : null,
            ),
            child: _isUploadingLogo
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : (_currentReportLogoPath == null && _reportLogoBytes == null ? Icon(Iconsax.image, color: Colors.grey) : null),
          ),
          const SizedBox(height: 8),
          const Text("Upload Logo", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCompactField(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        SizedBox(
          height: 45,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
                prefixIcon: Icon(icon, size: 16, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ClientTheme.primaryColor)),
                filled: true,
                fillColor: Colors.grey.shade50
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Frequency", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFrequency,
              isExpanded: true,
              style: TextStyle(fontSize: 13, color: ClientTheme.textDark),
              items: ['Immediate', 'Hourly', 'Daily'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _selectedFrequency = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFreqDropdown(String label, String? selected, ValueChanged<String?> onChanged, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          height: 45,
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8)
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Icon(icon, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    style: TextStyle(fontSize: 13, color: ClientTheme.textDark),
                    items: _freqOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool loading, VoidCallback onTap, String label) {
    return ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: ClientTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
      )
          : Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
      ],
      border: Border.all(color: Colors.grey.shade100),
    );
  }

  Widget _buildNoDevicePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(Iconsax.setting_2, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("No Device Selected", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text("Please select a device to configure settings.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadReportLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
    if (result == null) return;
    setState(() => _isUploadingLogo = true);
    try {
      Uint8List bytes;
      if (kIsWeb) bytes = result.files.first.bytes!;
      else bytes = await File(result.files.first.path!).readAsBytes();
      String fileName = await _imageUploadService.uploadClientLogo(bytes, "Report_${_reportCompanyController.text}");
      setState(() {
        _currentReportLogoPath = fileName;
        _reportLogoBytes = bytes;
        _isUploadingLogo = false;
      });
      _showSuccessSnackbar("Report Logo Uploaded");
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      _showErrorSnackbar("Upload failed");
    }
  }

  ImageProvider? _getReportImageProvider() {
    if (_reportLogoBytes != null) return MemoryImage(_reportLogoBytes!);
    if (_currentReportLogoPath != null && _currentReportLogoPath!.isNotEmpty) return NetworkImage("$_imageBaseUrl$_currentReportLogoPath");
    return null;
  }

  void _showEditProfileDialog() {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    final userData = provider.clientData ?? widget.userData;

    final nameCtrl = TextEditingController(text: userData['DisplayName']);
    final usernameCtrl = TextEditingController(text: userData['Username']);
    final emailCtrl = TextEditingController(text: userData['ContactEmail']);
    final addressCtrl = TextEditingController(text: userData['CompanyAddress']);

    String currentAvatarPath = userData['LogoPath'] ?? '';
    Uint8List? newAvatarBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: ClientTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Edit Profile", style: ClientTheme.themeData.textTheme.titleLarge),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: isUploading ? null : () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
                        if (result != null) {
                          setDialogState(() => isUploading = true);
                          try {
                            Uint8List bytes;
                            if (kIsWeb) bytes = result.files.first.bytes!;
                            else bytes = await File(result.files.first.path!).readAsBytes();
                            String fileName = await _imageUploadService.uploadClientLogo(bytes, "Profile_${usernameCtrl.text}");
                            setDialogState(() {
                              currentAvatarPath = fileName;
                              newAvatarBytes = bytes;
                              isUploading = false;
                            });
                          } catch (e) {
                            setDialogState(() => isUploading = false);
                          }
                        }
                      },
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ClientTheme.background,
                          border: Border.all(color: ClientTheme.primaryColor.withOpacity(0.3)),
                          image: newAvatarBytes != null
                              ? DecorationImage(image: MemoryImage(newAvatarBytes!), fit: BoxFit.cover)
                              : (currentAvatarPath.isNotEmpty
                              ? DecorationImage(image: NetworkImage("$_imageBaseUrl$currentAvatarPath"), fit: BoxFit.cover)
                              : null),
                        ),
                        child: isUploading
                            ? const CircularProgressIndicator()
                            : (newAvatarBytes == null && currentAvatarPath.isEmpty
                            ? Icon(Iconsax.camera, color: ClientTheme.textLight)
                            : null),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("Tap to change photo", style: TextStyle(fontSize: 10, color: ClientTheme.textLight)),
                    const SizedBox(height: 20),
                    _buildDialogTextField("Company Name", nameCtrl, Iconsax.building),
                    _buildDialogTextField("Username", usernameCtrl, Iconsax.user),
                    _buildDialogTextField("Email", emailCtrl, Iconsax.sms),
                    _buildDialogTextField("Address", addressCtrl, Iconsax.location),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white),
                onPressed: isUploading ? null : () async {
                  try {
                    final response = await http.post(
                      Uri.parse(_getApiBaseUrl('update_profile_api.php')),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({
                        "RecNo": userData['UserID'],
                        "Username": usernameCtrl.text,
                        "CompanyName": nameCtrl.text,
                        "CompanyAddress": addressCtrl.text,
                        "ContactEmail": emailCtrl.text,
                        "LogoPath": currentAvatarPath
                      }),
                    );
                    final result = jsonDecode(response.body);
                    if (result['status'] == 'success') {
                      if (context.mounted) {
                        Provider.of<ClientProvider>(context, listen: false).setClientData(result['data']);
                        Navigator.pop(context);
                        _showSuccessSnackbar("Profile Updated!");
                      }
                    } else {
                      _showErrorSnackbar(result['message'] ?? "Update Failed");
                    }
                  } catch (e) {
                    _showErrorSnackbar("Connection Error: $e");
                  }
                },
                child: const Text("Save Changes"),
              )
            ],
          );
        });
      },
    );
  }

  void _triggerResetPassword() {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    final userData = provider.clientData ?? widget.userData;
    final String username = userData['Username'];
    final String email = userData['ContactEmail'] ?? 'your email';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Reset Password"),
        content: Text("Send a password reset link to $email?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              try {
                final response = await http.post(
                  Uri.parse(_getApiBaseUrl('auth_api.php')),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({"action": "REQUEST_RESET", "username": username}),
                );
                final result = jsonDecode(response.body);
                if (mounted) Navigator.pop(context);
                if (result['status'] == 'success') {
                  showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Success"), content: Text("Reset link sent to ${result['masked_email']}"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
                } else {
                  _showErrorSnackbar(result['message'] ?? "Failed.");
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                _showErrorSnackbar("Connection failed.");
              }
            },
            child: const Text("Send Link"),
          )
        ],
      ),
    );
  }

  Widget _buildDialogTextField(String label, TextEditingController ctrl, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showErrorSnackbar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}