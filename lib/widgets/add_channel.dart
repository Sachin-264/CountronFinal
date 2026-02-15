// [UPDATE] lib/widgets/add_channel.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../AdminService/channel_api_service.dart';
import '../AdminService/input_type_api_service.dart';
import '../theme/app_theme.dart';

class AddChannelDialog extends StatefulWidget {
  final Function(String channelName) onSave;
  final Color? initialColor; // Receive unique color from ChannelScreen

  const AddChannelDialog({
    super.key,
    required this.onSave,
    this.initialColor,
  });

  @override
  State<AddChannelDialog> createState() => _AddChannelDialogState();
}

class _AddChannelDialogState extends State<AddChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ChannelApiService();
  final _inputTypeApiService = InputTypeApiService();

  bool _isLoading = false;
  bool _isCloseButtonHovered = false;

  List<Map<String, dynamic>> _inputTypeOptions = [];
  int? _selectedInputTypeID;
  bool get _isLinear => _selectedInputTypeID == 5;

  // Controllers
  final _channelIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();

  final _resolutionController = TextEditingController(text: '2');
  final _lowLimitsController = TextEditingController(text: '0.0');
  final _highLimitsController = TextEditingController(text: '100.0');
  final _lowValueController = TextEditingController(text: '-9999.0');
  final _highValueController = TextEditingController(text: '9999.0');
  final _offsetController = TextEditingController(text: '0.0');

  String? _suggestedId;

  Color _alarmColor = AppTheme.accentRed;
  late Color _lineColor; // Initialized in initState

  @override
  void initState() {
    super.initState();
    // Initialize with the unique color passed from parent or fallback to primary
    _lineColor = widget.initialColor ?? AppTheme.primaryBlue;
    _loadInputTypes();
    _fetchSuggestedId();
  }

  Future<void> _fetchSuggestedId() async {
    try {
      final id = await _apiService.generateChannelId();
      if (mounted) {
        setState(() {
          _suggestedId = id;
          _channelIdController.text = id;
        });
      }
    } catch (e) {
      debugPrint("Error fetching ID: $e");
    }
  }

  Future<void> _loadInputTypes() async {
    try {
      final types = await _inputTypeApiService.getAllInputTypes();
      setState(() {
        _inputTypeOptions = types;
        _selectedInputTypeID = types.firstWhere(
                (type) => type['InputTypeID'] == 1,
            orElse: () => types.firstWhere(
                    (type) => type['InputTypeID'] != 0,
                orElse: () => types.isNotEmpty ? types.first : {}
            )
        )['InputTypeID'] as int?;
      });
    } catch (e) {
      debugPrint("Error loading input types: $e");
    }
  }

  @override
  void dispose() {
    _channelIdController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _resolutionController.dispose();
    _lowLimitsController.dispose();
    _highLimitsController.dispose();
    _lowValueController.dispose();
    _highValueController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _saveChannel() async {
    if (!_formKey.currentState!.validate() || _selectedInputTypeID == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select an Input Type and fix the errors.'),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.createChannel(
        channelID: _channelIdController.text,
        channelName: _nameController.text,
        startingCharacter: '',
        dataLength: 8,
        channelInputType: _selectedInputTypeID!,
        resolution: int.tryParse(_resolutionController.text) ?? 2,
        unit: _unitController.text,
        lowLimits: double.tryParse(_lowLimitsController.text) ?? 0.0,
        highLimits: double.tryParse(_highLimitsController.text) ?? 100.0,
        offset: double.tryParse(_offsetController.text) ?? 0.0,
        targetAlarmColour: _colorToHex(_alarmColor),
        graphLineColour: _colorToHex(_lineColor),
        lowValue: _isLinear ? double.tryParse(_lowValueController.text) : null,
        highValue: _isLinear ? double.tryParse(_highValueController.text) : null,
      );

      widget.onSave(_nameController.text);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create channel: $e'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.background,
      surfaceTintColor: AppTheme.background,
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: MediaQuery.of(context).size.width * (isMobile ? 0.95 : 0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Iconsax.add, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('ADD NEW CHANNEL', style: theme.textTheme.titleLarge),
                  ),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isCloseButtonHovered = true),
                    onExit: (_) => setState(() => _isCloseButtonHovered = false),
                    child: AnimatedRotation(
                      turns: _isCloseButtonHovered ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: const Icon(Iconsax.close_circle),
                        color: AppTheme.bodyText.withOpacity(0.7),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderGrey),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextFormField(
                        controller: _channelIdController,
                        label: 'Channel ID *',
                        icon: Iconsax.tag,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      if (_suggestedId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Iconsax.info_circle, size: 14, color: AppTheme.primaryBlue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'System suggested ID: $_suggestedId',
                                  style: TextStyle(fontSize: 12, color: AppTheme.bodyText.withOpacity(0.8), fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildInputTypeDropdown(),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _nameController,
                        label: 'Channel Name',
                        icon: Iconsax.radar_2,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _unitController,
                        label: 'Unit *',
                        icon: Iconsax.ruler,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _resolutionController,
                        label: 'Resolution (Decimals) *',
                        icon: Iconsax.decred_dcr,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _offsetController,
                        label: 'Offset (-9999 to +9999) *',
                        icon: Iconsax.add_square,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final val = double.tryParse(v);
                          if (val == null) return 'Invalid';
                          if (val < -9999 || val > 9999) return 'Range Error';
                          return null;
                        },
                      ),
                      if (_isLinear) ...[
                        const Divider(height: 32),
                        _buildSectionHeader('Linear Calibration', Iconsax.setting_4, AppTheme.accentGreen),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: _lowValueController,
                          label: 'Low Value *',
                          icon: Iconsax.arrow_down_1,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: _highValueController,
                          label: 'High Value *',
                          icon: Iconsax.arrow_up_3,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        ),
                      ],
                      const Divider(height: 32),
                      _buildSectionHeader('Alarm Configuration', Iconsax.notification, AppTheme.accentRed),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _lowLimitsController,
                        label: 'Low Limit *',
                        icon: Iconsax.arrow_down_1,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _highLimitsController,
                        label: 'High Limit *',
                        icon: Iconsax.arrow_up_3,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                      const SizedBox(height: 16),
                      _buildColorPickerInput(
                        label: 'Alarm Color',
                        icon: Iconsax.color_swatch,
                        color: _alarmColor,
                        onColorChanged: (c) => setState(() => _alarmColor = c),
                      ),
                      const Divider(height: 32),
                      _buildSectionHeader('Chart Configuration', Iconsax.graph, AppTheme.accentGreen),
                      const SizedBox(height: 16),
                      _buildColorPickerInput(
                        label: 'Graph Line Color',
                        icon: Iconsax.colors_square,
                        color: _lineColor,
                        onColorChanged: (c) => setState(() => _lineColor = c),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedInputTypeID,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Input Type *',
          prefixIcon: Icon(Iconsax.activity, color: AppTheme.primaryBlue, size: 20),
          border: InputBorder.none,
        ),
        items: _inputTypeOptions.map((type) {
          return DropdownMenuItem<int>(
            value: type['InputTypeID'] as int,
            child: Text("${type['TypeName']} ${type['InputTypeID'] == 5 ? '(Linear)' : '(Non-Linear)'}"),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedInputTypeID = val),
        validator: (v) => v == null ? 'Required' : null,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(title.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        filled: true,
        fillColor: AppTheme.lightGrey.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
      ),
    );
  }

  Widget _buildColorPickerInput({required String label, required IconData icon, required Color color, required ValueChanged<Color> onColorChanged}) {
    return InkWell(
      onTap: () => _showColorPickerDialog(label, color, onColorChanged),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.lightGrey.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5))),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: AppTheme.bodyText.withOpacity(0.8), fontSize: 16)),
            const Spacer(),
            Container(width: 28, height: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderGrey))),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = currentColor;
        return AlertDialog(
          title: Text('Pick $title'),
          content: SingleChildScrollView(child: MaterialPicker(pickerColor: currentColor, onColorChanged: (color) => tempColor = color)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () { onColorChanged(tempColor); Navigator.pop(context); }, child: const Text('Select')),
          ],
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _saveChannel,
      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.add, size: 20),
      label: const Text('Create Channel', style: TextStyle(fontSize: 16, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}