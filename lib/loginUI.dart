import 'dart:convert';
import 'dart:ui'; // For ImageFilter
import 'package:countron_app/provider/admin_provider.dart';
import 'package:countron_app/provider/session_manager.dart';
import 'package:countron_app/widgets/constants.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Themes
import '../theme/app_theme.dart';
import '../routes/app_routes.dart'; // 2. Routes (for navigation)
import '../provider/client_provider.dart'; // 3. Client Provider

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isObscure = true;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  // --- LOAD REMEMBER ME DATA ---
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _usernameController.text = prefs.getString('username') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  String _getApiBaseUrl(String filename) {
    return "${ApiConstants.baseUrl}/$filename";
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Please enter both username and password.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(_getApiBaseUrl('login_api.php'));

      debugPrint("Attempting Login to: $url");

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "LOGIN",
          "Username": username,
          "Password": password,
        }),
      );

      debugPrint("Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Handle potential HTML garbage in response
        final jsonStartIndex = response.body.indexOf('{');
        final cleanBody = response.body.substring(jsonStartIndex);
        final data = jsonDecode(cleanBody);

        if (data['status'] == 'success') {
          final userData = data['data'];
          final role = userData['UserRole'];

          debugPrint("Login Success. Role: $role");

          // --- 1. SAVE PERMANENTLY (Remember Me) ---
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setBool('remember_me', true);
            await prefs.setString('username', username);
            await prefs.setString('password', password);
          } else {
            await prefs.clear();
          }

          // --- 2. SAVE SESSION (Browser Tab State) ---
          // This is crucial for the refresh logic!
          SessionManager.saveSession(role, userData);

          if (mounted) {
            if (role == 'Admin') {
              // Update Provider
              Provider.of<AdminProvider>(context, listen: false).setAdminData(userData);

              // 🚀 NAVIGATE USING NAMED ROUTE (Updates URL)
              Navigator.pushReplacementNamed(context, AppRoutes.admin);

            } else if (role == 'Client') {
              // Update Provider
              Provider.of<ClientProvider>(context, listen: false).setClientData(userData);

              // 🚀 NAVIGATE USING NAMED ROUTE (Updates URL)
              Navigator.pushReplacementNamed(context, AppRoutes.client);

            } else {
              setState(() => _errorMessage = "Unknown User Role: $role");
            }
          }
        } else {
          setState(() => _errorMessage = data['error'] ?? "Login failed");
        }
      } else {
        setState(() => _errorMessage = "Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("REAL ERROR: $e");
      setState(() => _errorMessage = "App Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Keep the rest of your UI code exactly the same: _showForgotPasswordDialog, build, etc.) ...

  void _showForgotPasswordDialog() {
    // ... [KEEP YOUR EXISTING CODE FOR DIALOG HERE] ...
    final TextEditingController resetUsernameController = TextEditingController();
    bool isResetLoading = false;
    String? resetMessage;
    bool isSuccess = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Reset Password", style: AppTheme.headline1.copyWith(fontSize: 20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Enter your username. We will send a reset link to your registered email.",
                      style: AppTheme.bodyText1),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetUsernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Iconsax.user),
                    ),
                  ),
                  if (resetMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        resetMessage!,
                        style: TextStyle(
                          color: isSuccess ? Colors.green[700] : Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isResetLoading ? null : () async {
                    final user = resetUsernameController.text.trim();
                    if (user.isEmpty) {
                      setDialogState(() {
                        resetMessage = "Please enter username";
                        isSuccess = false;
                      });
                      return;
                    }

                    setDialogState(() {
                      isResetLoading = true;
                      resetMessage = null;
                    });

                    try {
                      final url = Uri.parse(_getApiBaseUrl('auth_api.php'));
                      final response = await http.post(
                        url,
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "action": "REQUEST_RESET",
                          "username": user,
                        }),
                      );

                      final result = jsonDecode(response.body);

                      if (response.statusCode == 200 && result['status'] == 'success') {
                        String email = result['masked_email'] ?? 'your email';

                        setDialogState(() {
                          isResetLoading = false;
                          isSuccess = true;
                          resetMessage = "Link sent to $email\nLink is valid for 1 hour.";

                          if(result['debug_link'] != null) {
                            debugPrint("RESET LINK: ${result['debug_link']}");
                          }
                        });

                        Future.delayed(const Duration(seconds: 4), () {
                          if(context.mounted) Navigator.pop(context);
                        });
                      } else {
                        setDialogState(() {
                          isResetLoading = false;
                          isSuccess = false;
                          resetMessage = result['message'] ?? "Failed to process.";
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        isResetLoading = false;
                        isSuccess = false;
                        resetMessage = "Connection Error";
                      });
                    }
                  },
                  child: isResetLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Send Link", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... [KEEP YOUR EXISTING BUILD METHOD EXACTLY AS IS] ...
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: Stack(
        children: [
          _buildBackground(size),
          isDesktop ? _buildDesktopLayout(size) : _buildMobileLayout(size),
        ],
      ),
    );
  }

  // ... [KEEP ALL YOUR WIDGET HELPERS: _buildBackground, _buildDesktopLayout, _buildMobileLayout, _buildLoginFormContent, _buildAnimatedTextField, etc.] ...

  // Paste the rest of your UI building code here (I omitted it to keep the answer short, but you should keep it!).
  // Just ensure the _login() method and imports at the top match what I provided above.

  Widget _buildBackground(Size size) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              image: DecorationImage(
                image: NetworkImage('https://img.freepik.com/free-vector/white-abstract-background-design_23-2148825582.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -50,
          left: size.width * 0.3,
          child: _buildGlassCircle(250, color: AppTheme.primaryBlue.withOpacity(0.05)),
        ),
        Positioned(
          bottom: 100,
          right: -50,
          child: _buildGlassCircle(300, color: AppTheme.accentPink.withOpacity(0.05)),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Size size) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Positioned(
                top: 40,
                left: 40,
                child: const _CountronLogo(size: 48),
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2, end: 0),

              Positioned(
                top: size.height * 0.3,
                right: 80,
                child: _buildGlassCard(width: 70, height: 70, icon: Iconsax.cloud_connection),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -15, duration: 4.seconds),

              Positioned(
                bottom: size.height * 0.2,
                left: 80,
                child: _buildGlassCard(width: 90, height: 90, icon: Iconsax.security_safe),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 15, duration: 5.seconds),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 400,
                      width: 400,
                      child: Lottie.asset('assets/login.json', fit: BoxFit.contain),
                    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 800.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        Text("Smart Logger", style: AppTheme.headline1.copyWith(fontSize: 32, letterSpacing: 1.0)),
                        const SizedBox(height: 8),
                        Text("Monitor • Analyze • Control", style: AppTheme.stylizedHeading.copyWith(fontSize: 16, color: AppTheme.bodyText, fontWeight: FontWeight.w500, letterSpacing: 3.0)),
                      ],
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5, end: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _buildLoginFormContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Stack(
      children: [
        // 1. Logo - Fixed at Top (Thoda neeche, 60px par)
        const Positioned(
          top: 60,
          left: 24,
          child: _CountronLogo(size: 42),
        ),

        // 2. Login Card - "Center" hata kar padding se neeche shift kiya
        SizedBox.expand(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            // Top Padding 160 kar di taaki card neeche aa jaye
            padding: const EdgeInsets.fromLTRB(24, 140, 24, 30),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                    // isMobile: true zaroor pass karein
                    child: _buildLoginFormContent(isMobile: true),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 600.ms),
          ),
        ),
      ],
    );
  }
// Added optional parameter isMobile
  Widget _buildLoginFormContent({bool isMobile = false}) {
    int delay = 200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Welcome Back!", style: AppTheme.headline1.copyWith(fontSize: 32))
            .animate().fadeIn(delay: delay.ms).slideX(begin: -0.2, end: 0),
        const SizedBox(height: 8),
        Text("Enter your credentials to access your account.", style: AppTheme.bodyText1.copyWith(color: AppTheme.bodyText))
            .animate().fadeIn(delay: (delay += 100).ms).slideX(begin: -0.2, end: 0),
        const SizedBox(height: 40),
        _buildAnimatedTextField(
          controller: _usernameController,
          label: "Username",
          icon: Iconsax.user,
          delay: (delay += 100),
          // Add Hints
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 24),
        _buildAnimatedTextField(
          controller: _passwordController,
          label: "Password",
          icon: Iconsax.lock,
          isPassword: true,
          delay: (delay += 100),
          // Add Hints & Submit Action
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          // Trigger login when user hits "Enter" or "Done" on keyboard
          onSubmitted: _login,
        ),
        const SizedBox(height: 16),

        // --- CHANGED SECTION ---
        if (isMobile) ...[
          // Mobile Layout: Vertical Stack
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => _rememberMe = val!),
                ),
              ),
              Text("Remember me", style: AppTheme.bodyText1.copyWith(fontSize: 13)),
            ],
          ),
          // Forgot Password Moved Below
          Align(
            alignment: Alignment.centerRight, // Aligns to right (standard mobile UX)
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                "Forgot Password?",
                style: AppTheme.labelText.copyWith(color: AppTheme.primaryBlue, fontSize: 13),
              ),
            ),
          ),
        ] else ...[
          // Desktop Layout: Side by Side (Original)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) => setState(() => _rememberMe = val!),
                    ),
                  ),
                  Text("Remember me", style: AppTheme.bodyText1.copyWith(fontSize: 13)),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  "Forgot Password?",
                  style: AppTheme.labelText.copyWith(color: AppTheme.primaryBlue, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
        // --- END CHANGED SECTION ---

        const SizedBox(height: 32),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                Icon(Iconsax.warning_2, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTheme.bodyText1.copyWith(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ).animate().shake(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
                shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
                backgroundColor: Colors.transparent,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text("Sign In", style: AppTheme.buttonText.copyWith(fontSize: 16)),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: (delay += 100).ms).slideY(begin: 0.4, end: 0),
      ],
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    required int delay,
    // [ADD THESE PARAMETERS]
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelText.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.transparent),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && _isObscure,
            // [ADD THESE PROPERTIES]
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onSubmitted: (_) => onSubmitted?.call(),
            keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
            // -----------------------
            style: AppTheme.bodyText1.copyWith(
                color: AppTheme.darkText, fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              hintText: "Enter your ${label.toLowerCase()}",
              hintStyle: AppTheme.bodyText1.copyWith(
                  color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w400),
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(_isObscure ? Iconsax.eye_slash : Iconsax.eye,
                    color: Colors.grey[500], size: 20),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryBlue, width: 1.5)),
            ),
          ),
        ),
      ],
    ).animate(delay: delay.ms).fadeIn().slideX(begin: -0.1, end: 0);
  }

  Widget _buildGlassCircle(double size, {required Color color}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      ),
    );
  }

  Widget _buildGlassCard({required double width, required double height, required IconData icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width, height: height,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
          ),
          child: Center(child: Icon(icon, color: AppTheme.primaryBlue.withOpacity(0.7), size: 32)),
        ),
      ),
    );
  }
}

class _CountronLogo extends StatelessWidget {
  final double size;
  const _CountronLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.greatVibes(
          textStyle: AppTheme.logoStyle.copyWith(fontSize: size, fontWeight: FontWeight.bold),
        ),
        children: const [
          TextSpan(text: 'Count', style: TextStyle(color: AppTheme.primaryBlue)),
          TextSpan(text: 'ron.', style: TextStyle(color: AppTheme.accentPink)),
        ],
      ),
    );
  }
}