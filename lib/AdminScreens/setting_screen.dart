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

  // === UPDATED PROFILE CARD WITH LOGOUT ===
  Widget _buildAdminProfileCard(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final String adminName = adminProvider.adminName;
    final String adminEmail = adminProvider.email;
    final int adminRecNo = adminProvider.adminRecNo;

    return Container(
      width: isDesktop ? 600 : double.infinity,
      padding: const EdgeInsets.all(30),
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
          // Avatar and Name Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.4), blurRadius: 10)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        adminName.isNotEmpty ? adminName.split(' ').map((e) => e.isNotEmpty ? e.substring(0, 1) : '').take(2).join() : 'A',
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.background, width: 2),
                      ),
                      child: const Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Profile',
                      style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminName,
                      style: theme.textTheme.headlineMedium?.copyWith(color: AppTheme.darkText, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'System Administrator',
                      style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 30),

          _buildDetailRow(context, Iconsax.sms_tracking, 'Email', adminEmail),
          _buildDetailRow(context, Iconsax.user, 'Username', adminProvider.username),

          const SizedBox(height: 24),

          // === ACTION BUTTONS ROW ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. LOGOUT BUTTON (Left side)
              OutlinedButton.icon(
                onPressed: () {
                  // Clear Data
                  Provider.of<AdminProvider>(context, listen: false).clearData();
                  // Logout
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                },
                icon: Icon(Iconsax.logout, size: 18, color: AppTheme.accentRed),
                label: Text('Sign Out', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: AppTheme.accentRed.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // 2. CHANGE PASSWORD BUTTON (Right side)
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AdminResetPasswordDialog(adminRecNo: adminRecNo),
                  );
                },
                icon: const Icon(Iconsax.lock_1, size: 18),
                label: const Text('Change Password'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.darkText, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.bodyText),
                ),
              ],
            ),
          ),
          Icon(Iconsax.arrow_right_3, color: color, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final emailConfigCard = _buildPlaceholderCard(
      context,
      title: 'Email Configuration',
      subtitle: 'Manage SMTP settings for alerts and notifications.',
      icon: Iconsax.message_add,
      color: AppTheme.accentRed,
    );

    Widget buildTopSection() {
      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdminProfileCard(context, isDesktop: isDesktop),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'General Settings', Iconsax.global, AppTheme.accentGreen),
                  const SizedBox(height: 16),
                  emailConfigCard,
                ],
              ),
            ),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdminProfileCard(context, isDesktop: isDesktop),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'General Settings', Iconsax.global, AppTheme.accentGreen),
            const SizedBox(height: 16),
            emailConfigCard,
          ],
        );
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTopSection(),
          SizedBox(height: isDesktop ? 40 : 24),
          _buildSectionHeader(context, 'System Configuration', Iconsax.setting_4, AppTheme.accentPurple),
          SizedBox(height: isDesktop ? 24 : 16),
          _InputTypeMasterManager(),
          // Removed bottom logout button spacer
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ... (_InputTypeMasterManager remains exactly the same) ...
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
              title: Text('Create New Input Type'),
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
                          Spacer(),
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
                        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildEditField(
                        context,
                        _createMaxRangeController,
                        'Default Max Range *',
                        Iconsax.arrow_up_3,
                        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
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
                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildEditField(
                    context,
                    _editMaxRangeController,
                    'Default Max Range *',
                    Iconsax.arrow_up_3,
                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
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
                : 'Are you sure you want to permanently delete the custom input type "${inputType['TypeName']}"? This action cannot be undone. Any channels using this type will be affected.',
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
      _showSnackbar('Input Type deleted successfully!', isError: false);
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
      return Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
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
                icon: Icon(Iconsax.add_circle, size: 20),
                label: Text('Create New Type'),
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

          if (isDesktop)
            _buildInputTypeTable(context)
          else
            _buildInputTypeMobileList(context),
        ],
      ),
    );
  }

  // === IMPROVED MOBILE LAYOUT ===
  Widget _buildInputTypeMobileList(BuildContext context) {
    return ListView.separated(
      physics: NeverScrollableScrollPhysics(),
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
            boxShadow: [
              BoxShadow(color: AppTheme.shadowColor.withOpacity(0.05), blurRadius: 8)
            ],
          ),
          child: Column(
            children: [
              // Header Row
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                leading: Icon(
                  isLinear ? Iconsax.activity : Iconsax.truck_remove,
                  color: iconColor,
                ),
                title: Text(
                  '${type['TypeName']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'ID: ${type['InputTypeID']} • ${isLinear ? 'Linear' : 'Non-Linear'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.bodyText),
                ),
                trailing: IconButton(
                  icon: Icon(Iconsax.edit, color: AppTheme.accentPurple),
                  onPressed: () => _showEditDialog(type),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),

              // Body Rows
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    // Row 1: Min and Max Range
                    Row(
                      children: [
                        Expanded(child: _buildMobileInfoChip(context, 'Min Range', '${type['DefaultMinRange'] ?? '-'}', Iconsax.arrow_down_1)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMobileInfoChip(context, 'Max Range', '${type['DefaultMaxRange'] ?? '-'}', Iconsax.arrow_up_3)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Row 2: Decimals and Delete (Using available space)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Decimals (Only if non-linear)
                        if (!isLinear)
                          Expanded(child: _buildMobileInfoChip(context, 'Decimals', '${type['DefaultDecimalPlaces'] ?? '-'}', Iconsax.decred_dcr))
                        else
                          const Spacer(),

                        // Right: Delete Button with Proper Text
                        if (!isSystemType)
                          OutlinedButton.icon(
                            onPressed: () => _showDeleteConfirmDialog(type),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentRed,
                              side: BorderSide(color: AppTheme.accentRed.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Bigger padding
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Iconsax.trash, size: 18),
                            label: const Text('Delete Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), // Proper Text
                          )
                        else
                        // System Locked Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.borderGrey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.lock, size: 16, color: AppTheme.bodyText.withOpacity(0.5)),
                                const SizedBox(width: 8),
                                Text(
                                  "System Locked",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.bodyText.withOpacity(0.6)
                                  ),
                                ),
                              ],
                            ),
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

  // Mobile Info Chip Helper
  Widget _buildMobileInfoChip(BuildContext context, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.bodyText.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.darkText)),
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
        5: FixedColumnWidth(50), // Edit
        6: FixedColumnWidth(50), // Delete
      },
      children: [
        _buildTableHeaderRow(context),
        ..._inputTypes.map((type) => _buildTableRow(context, type)).toList(),
      ],
    );
  }

  TableRow _buildTableHeaderRow(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryBlue,
    );
    return TableRow(
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      children: [
        _buildHeaderCell(context, 'ID', style),
        _buildHeaderCell(context, 'Type Name', style),
        _buildHeaderCell(context, 'Linear', style),
        _buildHeaderCell(context, 'Min Range', style),
        _buildHeaderCell(context, 'Max Range', style),
        _buildHeaderCell(context, 'Edit', style, TextAlign.center),
        _buildHeaderCell(context, 'Del', style, TextAlign.center),
      ],
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text, TextStyle? style, [TextAlign align = TextAlign.left]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(text, style: style, textAlign: align),
    );
  }

  TableRow _buildTableRow(BuildContext context, Map<String, dynamic> type) {
    final bool isSystemType = type['InputTypeID'] >= 0 && type['InputTypeID'] <= 5;
    final bool isLinear = type['IsLinear'] == 1 || type['IsLinear'] == true;
    final Color rowColor = isSystemType ? AppTheme.lightGrey.withOpacity(0.5) : Colors.transparent;

    final cellStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppTheme.darkText,
      fontWeight: FontWeight.w500,
    );

    return TableRow(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
      ),
      children: [
        _buildTableCell(context, '${type['InputTypeID']}', cellStyle, TextAlign.center),
        _buildTableCell(context, type['TypeName'], cellStyle),
        _buildTableCell(
            context,
            isLinear ? 'Yes' : 'No',
            cellStyle?.copyWith(color: isLinear ? AppTheme.accentPink : AppTheme.primaryBlue)
        ),
        _buildTableCell(context, '${type['DefaultMinRange'] ?? '-'}', cellStyle),
        _buildTableCell(context, '${type['DefaultMaxRange'] ?? '-'}', cellStyle),
        // Edit Button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: IconButton(
              icon: Icon(Iconsax.edit, size: 18, color: AppTheme.accentPurple),
              onPressed: () => _showEditDialog(type),
              tooltip: 'Edit Ranges',
            ),
          ),
        ),
        // Delete Button (Disabled for System Types 0-5)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: IconButton(
              icon: Icon(Iconsax.trash, size: 18, color: isSystemType ? AppTheme.borderGrey : AppTheme.accentRed),
              onPressed: isSystemType ? null : () => _showDeleteConfirmDialog(type),
              tooltip: isSystemType ? 'Cannot delete system type' : 'Delete Custom Type',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(BuildContext context, String text, TextStyle? style, [TextAlign align = TextAlign.left]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(text, style: style, textAlign: align),
    );
  }
}