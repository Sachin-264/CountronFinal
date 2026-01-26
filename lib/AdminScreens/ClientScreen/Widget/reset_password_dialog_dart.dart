// [UPDATE] lib/widgets/reset_password_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../AdminService/client_api_service.dart';
import '../../../theme/app_theme.dart';

class ResetPasswordDialog extends StatefulWidget {
  final Map<String, dynamic> client;
  final String? currentPassword; // <--- Added Parameter
  final VoidCallback onSave;

  const ResetPasswordDialog({
    super.key,
    required this.client,
    this.currentPassword, // <--- Receive it here
    required this.onSave,
  });

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ClientApiService _apiService = ClientApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigits = false;

  @override
  void initState() {
    super.initState();
    // Use the explicitly passed password, or fallback to map, or 'N/A'
    _currentPasswordController.text = widget.currentPassword ?? widget.client['Password'] ?? 'N/A';

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
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasMinLength || !_hasUppercase || !_hasDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password does not meet all requirements.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.resetClientPassword(
        recNo: widget.client['RecNo'],
        newPasswordHash: _passwordController.text,
      );
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset password: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          Icon(Iconsax.key, color: AppTheme.accentYellow),
          SizedBox(width: 12),
          Text('Reset Password', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Updating password for ${widget.client['CompanyName']}",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // === Current Password Field (Read Only) ===
              _buildTextFormField(
                controller: _currentPasswordController,
                label: 'Current Password',
                icon: Iconsax.lock_1,
                readOnly: true,
                isPassword: false,
                suffixIcon: IconButton(
                  icon: Icon(Iconsax.copy, color: AppTheme.primaryBlue),
                  tooltip: 'Copy Password',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentPasswordController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Password copied to clipboard'),
                        backgroundColor: AppTheme.accentGreen,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 32, color: AppTheme.borderGrey.withOpacity(0.5)),

              _buildTextFormField(
                controller: _passwordController,
                label: 'New Password *',
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
          onPressed: _isLoading ? null : _handleResetPassword,
          icon: _isLoading
              ? Container(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Iconsax.save_2, size: 18),
          label: const Text('Save Password'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentYellow,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool isPassword = false,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isPassword,
      readOnly: readOnly,
      style: const TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly
            ? AppTheme.lightGrey.withOpacity(0.8)
            : AppTheme.lightGrey.withOpacity(0.5),
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
      ),
    );
  }
}