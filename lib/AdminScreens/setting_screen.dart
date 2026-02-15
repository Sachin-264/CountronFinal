// [UPDATE] lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../provider/admin_provider.dart';
import '../AdminService/input_type_api_service.dart';
import '../theme/app_theme.dart';
import '../../loginUI.dart';
import '../widgets/admin_reset_password.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2), thickness: 1)),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.bodyText.withOpacity(0.8)),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.bodyText, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.darkText, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // === UPDATED PROFILE CARD (Sign Out in Header, No Row Overflow) ===
// === IMPROVED PROFILE CARD FOR MOBILE ===
  Widget _buildAdminProfileCard(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final String adminName = adminProvider.adminName;
    final String adminEmail = adminProvider.email;
    final int adminRecNo = adminProvider.adminRecNo;

    return Container(
      width: isDesktop ? 600 : double.infinity,
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.background, AppTheme.lightGrey.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Name & Logout (Avatar Removed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADMIN ACCOUNT',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Provider.of<AdminProvider>(context, listen: false).clearData();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                },
                icon: Icon(Iconsax.logout, color: AppTheme.accentRed),
                tooltip: 'Sign Out',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentRed.withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),

          const Divider(height: 32),

          // Detail Rows: Vertical stacking for mobile to prevent email cutting
          _buildResponsiveDetail(context, Iconsax.sms_tracking, 'Email Address', adminEmail, isDesktop),
          const SizedBox(height: 16),
          _buildResponsiveDetail(context, Iconsax.user, 'Username', adminProvider.username, isDesktop),
          const SizedBox(height: 16),
          _buildResponsiveDetail(context, Iconsax.verify, 'System Role', 'Administrator', isDesktop),

          const SizedBox(height: 30),

          // Full width Change Password Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AdminResetPasswordDialog(adminRecNo: adminRecNo),
                );
              },
              icon: const Icon(Iconsax.lock_1, size: 20),
              label: const Text('Change Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }

// Helper Widget to switch between horizontal and vertical detail views
  Widget _buildResponsiveDetail(BuildContext context, IconData icon, String label, String value, bool isDesktop) {
    if (isDesktop) {
      // Standard horizontal row for wide screens
      return _buildDetailRow(context, icon, label, value);
    } else {
      // Stacked layout for Mobile to allow long emails/text
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryBlue.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.bodyText,
                    fontWeight: FontWeight.w600
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.bold
              ),
              softWrap: true,
              overflow: TextOverflow.visible, // Ensures long emails wrap to next line instead of cutting
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Only Profile Card
          _buildAdminProfileCard(context, isDesktop: isDesktop),

          SizedBox(height: isDesktop ? 40 : 24),

          // System Configuration Section
          _buildSectionHeader(context, 'System Configuration', Iconsax.setting_4, AppTheme.accentPurple),
          SizedBox(height: isDesktop ? 24 : 16),
          _InputTypeMasterManager(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// === InputTypeMasterManager (Logical Master for CRUD) ===
class _InputTypeMasterManager extends StatefulWidget {
  @override
  __InputTypeMasterManagerState createState() => __InputTypeMasterManagerState();
}

class __InputTypeMasterManagerState extends State<_InputTypeMasterManager> {
  final InputTypeApiService _apiService = InputTypeApiService();
  List<Map<String, dynamic>> _inputTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInputTypes();
  }

  Future<void> _loadInputTypes() async {
    setState(() => _isLoading = true);
    try {
      final types = await _apiService.getAllInputTypes();
      setState(() {
        _inputTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Failed to load input types: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateDialog() {
    final _formKey = GlobalKey<FormState>();
    final _createTypeNameController = TextEditingController();
    final _createMinRangeController = TextEditingController(text: '0.0');
    final _createMaxRangeController = TextEditingController(text: '100.0');
    final _createDecimalController = TextEditingController(text: '0');
    bool _isLinearInput = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Create New Input Type'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEditField(context, _createTypeNameController, 'Type Name *', Iconsax.text_block, validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Is Linear?', style: Theme.of(context).textTheme.bodyLarge),
                          const Spacer(),
                          Switch(
                            value: _isLinearInput,
                            onChanged: (bool value) {
                              setState(() {
                                _isLinearInput = value;
                              });
                            },
                            activeColor: AppTheme.accentPink,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_isLinearInput)
                        _buildEditField(
                          context,
                          _createDecimalController,
                          'Default Decimals (Non-Linear) *',
                          Iconsax.decred_dcr,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      const SizedBox(height: 12),
                      _buildEditField(
                        context,
                        _createMinRangeController,
                        'Default Min Range *',
                        Iconsax.arrow_down_1,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildEditField(
                        context,
                        _createMaxRangeController,
                        'Default Max Range *',
                        Iconsax.arrow_up_3,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppTheme.bodyText))),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _createInputType(
                        _createTypeNameController.text,
                        _isLinearInput,
                        double.tryParse(_createMinRangeController.text),
                        double.tryParse(_createMaxRangeController.text),
                        _isLinearInput ? null : int.tryParse(_createDecimalController.text),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> inputType) {
    final _formKey = GlobalKey<FormState>();
    final bool isSystemType = inputType['InputTypeID'] >= 0 && inputType['InputTypeID'] <= 5;

    final _editTypeNameController = TextEditingController(text: inputType['TypeName']);
    final _editMinRangeController = TextEditingController(text: inputType['DefaultMinRange']?.toString() ?? '');
    final _editMaxRangeController = TextEditingController(text: inputType['DefaultMaxRange']?.toString() ?? '');
    final _editDecimalController = TextEditingController(text: inputType['DefaultDecimalPlaces']?.toString() ?? '');

    final bool isLinear = inputType['IsLinear'] == 1 || inputType['IsLinear'] == true;
    final Color color = isLinear ? AppTheme.accentPink : AppTheme.primaryBlue;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit Input Type: ${inputType['InputTypeID']} (${isSystemType ? "System Type" : "Custom"})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEditField(
                    context,
                    _editTypeNameController,
                    'Type Name',
                    Iconsax.text_block,
                    readOnly: isSystemType,
                    validator: (v) => isSystemType ? null : (v!.isEmpty ? 'Required' : null),
                  ),
                  if (isSystemType)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                          'System types (0-5) can only have their ranges modified.',
                          style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),

                  if (!isLinear)
                    _buildEditField(
                      context,
                      _editDecimalController,
                      'Default Decimals (Non-Linear) *',
                      Iconsax.decred_dcr,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  const SizedBox(height: 12),
                  _buildEditField(
                    context,
                    _editMinRangeController,
                    'Default Min Range *',
                    Iconsax.arrow_down_1,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildEditField(
                    context,
                    _editMaxRangeController,
                    'Default Max Range *',
                    Iconsax.arrow_up_3,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.bodyText)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _updateInputType(
                    inputType['InputTypeID'],
                    _editTypeNameController.text,
                    double.tryParse(_editMinRangeController.text),
                    double.tryParse(_editMaxRangeController.text),
                    isLinear ? null : int.tryParse(_editDecimalController.text),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> inputType) {
    final bool isSystemType = inputType['InputTypeID'] >= 0 && inputType['InputTypeID'] <= 5;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isSystemType ? 'Cannot Delete System Type' : 'Confirm Deletion',
            style: TextStyle(color: isSystemType ? AppTheme.accentRed : AppTheme.darkText),
          ),
          content: Text(
            isSystemType
                ? 'Input Type ID ${inputType['InputTypeID']} is a fundamental system type ("${inputType['TypeName']}") and cannot be deleted.'
                : 'Are you sure you want to permanently delete the custom input type "${inputType['TypeName']}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppTheme.bodyText)),
            ),
            if (!isSystemType)
              ElevatedButton(
                onPressed: () => _deleteInputType(inputType['InputTypeID']),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _createInputType(String name, bool isLinear, double? min, double? max, int? decimals) async {
    Navigator.pop(context);
    try {
      await _apiService.createInputType(
        typeName: name,
        isLinear: isLinear,
        defaultMinRange: min!,
        defaultMaxRange: max!,
        defaultDecimalPlaces: decimals,
      );
      _loadInputTypes();
      _showSnackbar('Input Type "$name" created successfully!');
    } catch (e) {
      _showSnackbar('Failed to create: ${e.toString()}', isError: true);
    }
  }

  Future<void> _updateInputType(int id, String name, double? min, double? max, int? decimals) async {
    Navigator.pop(context);
    try {
      await _apiService.updateInputType(
        id: id,
        typeName: name,
        defaultMinRange: min,
        defaultMaxRange: max,
        defaultDecimalPlaces: decimals,
      );
      _loadInputTypes();
      _showSnackbar('Input Type updated successfully!');
    } catch (e) {
      _showSnackbar('Failed to update: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteInputType(int id) async {
    Navigator.pop(context);
    try {
      await _apiService.deleteInputType(id: id);
      _loadInputTypes();
      _showSnackbar('Input Type deleted successfully!');
    } catch (e) {
      _showSnackbar('Failed to delete: ${e.toString()}', isError: true);
    }
  }

  Widget _buildEditField(
      BuildContext context,
      TextEditingController controller,
      String label,
      IconData icon,
      {TextInputType keyboardType = TextInputType.text, bool readOnly = false, String? Function(String?)? validator, List<TextInputFormatter>? inputFormatters}
      ) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.darkText),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: readOnly ? AppTheme.lightGrey.withOpacity(0.8) : AppTheme.lightGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: AppTheme.shadowColor.withOpacity(0.08), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Input Type Master',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.darkText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Iconsax.add_circle, size: 20),
                label: const Text('Create New Type'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isDesktop ? _buildInputTypeTable(context) : _buildInputTypeMobileList(context),
        ],
      ),
    );
  }

  Widget _buildInputTypeMobileList(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _inputTypes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final type = _inputTypes[index];
        final bool isSystemType = type['InputTypeID'] >= 0 && type['InputTypeID'] <= 5;
        final bool isLinear = type['IsLinear'] == 1 || type['IsLinear'] == true;
        final Color iconColor = isLinear ? AppTheme.accentPink : AppTheme.primaryBlue;

        return Container(
          decoration: BoxDecoration(
            color: isSystemType ? AppTheme.lightGrey.withOpacity(0.5) : AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(isLinear ? Iconsax.activity : Iconsax.truck_remove, color: iconColor),
                title: Text('${type['TypeName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${type['InputTypeID']} • ${isLinear ? 'Linear' : 'Non-Linear'}'),
                trailing: IconButton(
                  icon: Icon(Iconsax.edit, color: AppTheme.accentPurple),
                  onPressed: () => _showEditDialog(type),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMobileInfoChip(context, 'Min', '${type['DefaultMinRange'] ?? '-'}', Iconsax.arrow_down_1)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMobileInfoChip(context, 'Max', '${type['DefaultMaxRange'] ?? '-'}', Iconsax.arrow_up_3)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isLinear)
                          _buildMobileInfoChip(context, 'Decimals', '${type['DefaultDecimalPlaces'] ?? '-'}', Iconsax.decred_dcr)
                        else
                          const SizedBox(),
                        if (!isSystemType)
                          OutlinedButton.icon(
                            onPressed: () => _showDeleteConfirmDialog(type),
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
                            icon: const Icon(Iconsax.trash, size: 16),
                            label: const Text('Delete'),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileInfoChip(BuildContext context, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppTheme.bodyText),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputTypeTable(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FixedColumnWidth(50),
        6: FixedColumnWidth(50),
      },
      children: [
        _buildTableHeaderRow(context),
        ..._inputTypes.map((type) => _buildTableRow(context, type)).toList(),
      ],
    );
  }

  TableRow _buildTableHeaderRow(BuildContext context) {
    final style = TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue);
    return TableRow(
      decoration: BoxDecoration(color: AppTheme.lightGrey.withOpacity(0.5)),
      children: [
        _buildTableCell(context, 'ID', style, TextAlign.center),
        _buildTableCell(context, 'Type Name', style),
        _buildTableCell(context, 'Linear', style),
        _buildTableCell(context, 'Min', style),
        _buildTableCell(context, 'Max', style),
        const SizedBox(),
        const SizedBox(),
      ],
    );
  }

  TableRow _buildTableRow(BuildContext context, Map<String, dynamic> type) {
    final bool isSystemType = type['InputTypeID'] >= 0 && type['InputTypeID'] <= 5;
    return TableRow(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderGrey.withOpacity(0.3)))),
      children: [
        _buildTableCell(context, '${type['InputTypeID']}', null, TextAlign.center),
        _buildTableCell(context, type['TypeName'], null),
        _buildTableCell(context, type['IsLinear'] == 1 ? 'Yes' : 'No', null),
        _buildTableCell(context, '${type['DefaultMinRange'] ?? '-'}', null),
        _buildTableCell(context, '${type['DefaultMaxRange'] ?? '-'}', null),
        IconButton(icon: Icon(Iconsax.edit, size: 18, color: AppTheme.accentPurple), onPressed: () => _showEditDialog(type)),
        IconButton(icon: Icon(Iconsax.trash, size: 18, color: isSystemType ? Colors.grey : AppTheme.accentRed), onPressed: isSystemType ? null : () => _showDeleteConfirmDialog(type)),
      ],
    );
  }

  Widget _buildTableCell(BuildContext context, String text, TextStyle? style, [TextAlign align = TextAlign.left]) {
    return Padding(padding: const EdgeInsets.all(12), child: Text(text, style: style, textAlign: align));
  }
}