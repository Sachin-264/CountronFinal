import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../AdminService/reset_api_service.dart';
import '../../theme/app_theme.dart';

class AdminResetPasswordDialog extends StatefulWidget {
  final int adminRecNo;

  const AdminResetPasswordDialog({super.key, required this.adminRecNo});

  @override
  State<AdminResetPasswordDialog> createState() => _AdminResetPasswordDialogState();
}

class _AdminResetPasswordDialogState extends State<AdminResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  final ResetApiService _apiService = ResetApiService();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.resetPassword(
        targetType: 'ADMIN',
        recNo: widget.adminRecNo,
        newPassword: _passController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);

      _showSuccessOverlay(); // Show a custom beautiful overlay

    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessOverlay() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Password updated successfully!', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Transparent for custom shape
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420), // Optimal width for desktop/tablet
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // === 1. VISUAL HEADER ===
              Stack(
                children: [
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.accentPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: const Icon(Iconsax.shield_security, color: Colors.white, size: 48),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              // === 2. CONTENT BODY ===
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "Secure Your Account",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter a new strong password below to update your admin credentials.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppTheme.bodyText.withOpacity(0.8), height: 1.4),
                      ),
                      const SizedBox(height: 32),

                      // Password Fields
                      _buildModernPasswordField(
                        controller: _passController,
                        label: 'New Password',
                        isObscured: _obscurePass,
                        onToggle: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      const SizedBox(height: 20),
                      _buildModernPasswordField(
                        controller: _confirmController,
                        label: 'Confirm Password',
                        isObscured: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please confirm your password';
                          if (val != _passController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleReset,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Iconsax.lock_1, size: 20, color: Colors.white),
                                    SizedBox(width: 10),
                                    Text("Update Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.bodyText),
                        child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }

  Widget _buildModernPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      validator: validator ?? (val) => (val == null || val.length < 6) ? 'Password must be at least 6 characters' : null,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.7)),
        floatingLabelStyle: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
        prefixIcon: Icon(Iconsax.key, color: AppTheme.primaryBlue.withOpacity(0.7), size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            isObscured ? Iconsax.eye_slash : Iconsax.eye,
            color: AppTheme.bodyText.withOpacity(0.6),
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppTheme.lightGrey.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.accentRed.withOpacity(0.5), width: 1.5),
        ),
      ),
    );
  }
}