// [UPDATE] lib/widgets/device_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../AdminService/client_api_service.dart'; // Import your API service
import '../../../theme/app_theme.dart';
import '../../../widgets/add_client_dialog.dart';

class DeviceFormDialog extends StatefulWidget {
  final Function(DeviceData) onSave;
  final String generatedSerial;

  const DeviceFormDialog({
    required this.onSave,
    required this.generatedSerial,
    super.key,
  });

  @override
  State<DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<DeviceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ClientApiService _apiService = ClientApiService(); // Initialize API service

  final _nameController = TextEditingController();
  final _serialController = TextEditingController();
  final _channelCountController = TextEditingController();

  String _selectedLocation = 'India';
  String _displayId = "Loading..."; // To show MMYYxxxx
  bool _isLoadingId = true;

// Full List of Countries

  static const List<String> _countries = [

    'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Antigua and Barbuda',

    'Argentina', 'Armenia', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas',

    'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin',

    'Bhutan', 'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei',

    'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia', 'Cameroon',

    'Canada', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia',

    'Comoros', 'Congo (Congo-Brazzaville)', 'Costa Rica', 'Croatia', 'Cuba',

    'Cyprus', 'Czechia (Czech Republic)', 'Democratic Republic of the Congo',

    'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt',

    'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini (fmr. "Swaziland")',

    'Ethiopia', 'Fiji', 'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany',

    'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana',

    'Haiti', 'Holy See', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran',

    'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan',

    'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho',

    'Liberia', 'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar',

    'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania',

    'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro',

    'Morocco', 'Mozambique', 'Myanmar (formerly Burma)', 'Namibia', 'Nauru', 'Nepal',
    'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'North Korea',
    'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine State',
    'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Poland',
    'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda', 'Saint Kitts and Nevis',
    'Saint Lucia', 'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
    'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
    'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia',
    'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan',
    'Suriname', 'Sweden', 'Switzerland', 'Syria', 'Tajikistan', 'Tanzania', 'Thailand',
    'Timor-Leste', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey',
    'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates',
    'United Kingdom', 'United States of America', 'Uruguay', 'Uzbekistan', 'Vanuatu',
    'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe'

  ];

  @override
  void initState() {
    super.initState();
    _serialController.text = widget.generatedSerial;
    _generatePreviewId(); // Fetch next ID on startup
  }

  // MMYYxxxx generation logic
  Future<void> _generatePreviewId() async {
    try {
      final int nextValue = await _apiService.getNextDeviceRecNo();
      final now = DateTime.now();
      String month = now.month.toString().padLeft(2, '0');
      String year = now.year.toString().substring(2);
      String paddedCount = nextValue.toString().padLeft(4, '0');

      setState(() {
        _displayId = "$month$year$paddedCount";
        _isLoadingId = false;
      });
    } catch (e) {
      setState(() {
        _displayId = "Error fetching ID";
        _isLoadingId = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _channelCountController.dispose();
    super.dispose();
  }

  void _saveDevice() {
    if (_formKey.currentState!.validate()) {
      final device = DeviceData(
        name: _nameController.text,
        serial: _serialController.text,
        channelCount: int.tryParse(_channelCountController.text) ?? 0,
        location: _selectedLocation,
      );
      widget.onSave(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.background,
      surfaceTintColor: AppTheme.background,
      title: Row(
        children: [
          Icon(Iconsax.cpu, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Text('Add New Device', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. MMYYxxxx READ-ONLY FIELD ---
              _buildReadOnlyIdField(),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _nameController,
                label: 'Device Name *',
                icon: Iconsax.device_message,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _serialController,
                label: 'Serial Number *',
                icon: Iconsax.barcode,
                readOnly: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _channelCountController,
                label: 'Channel Count *',
                icon: Iconsax.radar_2,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // --- Location Autocomplete ---
              _buildLocationAutocomplete(),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppTheme.bodyText)),
        ),
        ElevatedButton.icon(
          // Disable button until ID is loaded to prevent errors
          onPressed: _isLoadingId ? null : _saveDevice,
          icon: _isLoadingId
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Iconsax.add, size: 18),
          label: const Text('Add Device'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Custom widget to display the MMYYxxxx ID prominently
  Widget _buildReadOnlyIdField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.personalcard, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Generated Device ID (MMYYxxxx)',
                  style: TextStyle(fontSize: 10, color: AppTheme.bodyText.withOpacity(0.8))),
              _isLoadingId
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_displayId, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  // Your existing Autocomplete logic
  Widget _buildLocationAutocomplete() {
    return Autocomplete<String>(
      initialValue: const TextEditingValue(text: 'India'),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') return const Iterable<String>.empty();
        return _countries.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) => _selectedLocation = selection,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        controller.addListener(() => _selectedLocation = controller.text);
        return _buildTextFormField(
          controller: controller,
          label: 'Device Location',
          icon: Iconsax.location_tick,
          focusNode: focusNode,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.background,
            child: SizedBox(
              width: 250,
              height: 300,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (ctx, index) => ListTile(
                  title: Text(options.elementAt(index), style: const TextStyle(color: AppTheme.darkText)),
                  onTap: () => onSelected(options.elementAt(index)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      focusNode: focusNode,
      style: TextStyle(color: readOnly ? AppTheme.bodyText : AppTheme.darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        filled: true,
        fillColor: readOnly ? AppTheme.lightGrey : AppTheme.lightGrey.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
      ),
    );
  }
}