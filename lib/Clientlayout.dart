// [UPDATE] lib/Clientlayout.dart

import 'dart:ui';
import 'package:countron_app/provider/admin_provider.dart';
import 'package:countron_app/theme/app_theme.dart';
import 'package:countron_app/theme/client_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../loginUI.dart';
import '../provider/client_provider.dart';
import '../provider/session_manager.dart'; // 🆕 IMPORT SESSION MANAGER
// 🔑 IMPORT: deviceConfigScreenKey from device_configure.dart
import 'ClientScreen/Download/download.dart';
import 'ClientScreen/Setting/client_setting_screen.dart';
import 'ClientScreen/device_configure.dart';
// 🔑 NEW IMPORT: AllChannelConfigScreen for the new menu item
import 'ClientScreen/all_channel_config_screen.dart';
import 'ClientScreen/wifi_setup_widget.dart';


// === CLIENT SPECIFIC ENUM ===
enum ClientScreen {
  devices,   // Index 0
  configure, // Index 1
  settings,  // Index 2
  downloads, // 🆕 Added for Mobile Download History
}
// === LOGO WIDGET ===
class _StyledLogoText extends StatelessWidget {
  final double size;
  const _StyledLogoText({required this.size});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: ClientTheme.logoStyle.copyWith(
          fontSize: 40,
          letterSpacing: 0.5,
        ),
        children: [
          TextSpan(
            text: 'Count',
            style: TextStyle(color: ClientTheme.primaryColor),
          ),
          TextSpan(
            text: 'ron.',
            style: TextStyle(color: ClientTheme.secondaryColor),
          ),
        ],
      ),
    );
  }
}

class ClientLayout extends StatefulWidget {
  final Widget child;
  final ClientScreen activeScreen;
  final Function(ClientScreen) onScreenSelected;
  final Map<String, dynamic> userData;

  const ClientLayout({
    super.key,
    required this.child,
    required this.activeScreen,
    required this.onScreenSelected,
    required this.userData,
  });

  @override
  State<ClientLayout> createState() => _ClientLayoutState();
}

class _ClientLayoutState extends State<ClientLayout> with SingleTickerProviderStateMixin {
  // === DESKTOP SIDEBAR STATE ===
  bool _isSidebarCollapsed = false;
  static const String _imageBaseUrl = "https://storage.googleapis.com/upload-images-34/images/LMS/";

  // === MOBILE ANIMATED SIDEBAR STATE ===
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _offsetAnimation;
  late Animation<double> _borderRadiusAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    const curve = Curves.elasticOut;

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(CurvedAnimation(
      parent: _animationController,
      curve: curve,
    ));

    _offsetAnimation = Tween<double>(begin: 0.0, end: 260.0).animate(CurvedAnimation(
      parent: _animationController,
      curve: curve,
    ));

    _borderRadiusAnimation = Tween<double>(begin: 0.0, end: 30.0).animate(CurvedAnimation(
      parent: _animationController,
      curve: curve,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 🆕 NEW: Middleware to Save Session before notifying Parent
  void _handleScreenSelection(ClientScreen screen) {
    // 1. Save the tab name to Session Storage
    SessionManager.saveCurrentTab(screen.toString().split('.').last);

    // 2. Notify the parent widget to update the UI
    widget.onScreenSelected(screen);
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
    if (_isSidebarOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  // 🔑 LOGO WIDGET
  Widget _buildLogo({double size = 40, bool useImage = false}) {
    if (useImage) {
      return Image.asset(
        'assets/images/countron.jpeg',
        width: 60,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ClientTheme.primaryColor],
              ),
            ),
            child: Center(child: Icon(Iconsax.activity, color: Colors.white, size: size * 0.5)),
          );
        },
      );
    }
    return _StyledLogoText(size: size);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    final showMobileNav = isMobile && !_isSidebarOpen &&
        (widget.activeScreen == ClientScreen.devices || widget.activeScreen == ClientScreen.configure || widget.activeScreen == ClientScreen.settings||widget.activeScreen == ClientScreen.downloads);

    return Scaffold(
      backgroundColor: ClientTheme.background,
      bottomNavigationBar: showMobileNav ? _buildBottomAppBar(context) : null,
      floatingActionButton: showMobileNav ? _buildStartFab(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ClientTheme.primaryColor.withOpacity(0.05),
              ),
            ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut),
          ),

          isMobile
              ? _buildAnimatedMobileContent(isMobile)
              : Row(
            children: [
              _buildDesktopSidebar(),
              Expanded(child: _buildMainContentArea(isMobile)),
            ],
          ),

          if (isMobile) _buildMobileSidebar(),
        ],
      ),
    );
  }

  // =================================================================
  // === MOBILE SIDEBAR & ANIMATION LOGIC ===
  // =================================================================

  Widget _buildAnimatedMobileContent(bool isMobile) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..translate(_offsetAnimation.value)
            ..scale(_scaleAnimation.value),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
            child: GestureDetector(
              onTap: _isSidebarOpen ? _toggleSidebar : null,
              child: AbsorbPointer(
                absorbing: _isSidebarOpen,
                child: Container(
                  color: ClientTheme.background.withOpacity(_isSidebarOpen ? 0.9 : 1.0),
                  child: _buildMainContentArea(isMobile),
                ),
              ),
            ),
          ),
        );
      },
      child: _buildMainContentArea(isMobile),
    );
  }


  Future<void> _showLogoutConfirmation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ClientTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Capture provider references BEFORE navigation context is lost
      final clientProvider = Provider.of<ClientProvider>(context, listen: false);
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      // 1. Clear Session Storage (Async)
      // We wait for this to ensure disk storage is clean before moving on
      await SessionManager.clearSession();

      if (mounted) {
        // 2. Navigate FIRST to remove the current screen and listeners
        // This prevents 'DeviceSelectionScreen' from rebuilding
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login', // Ensure this matches your AppRoutes.login string
              (route) => false,
        );

        // 3. Clear Provider Data AFTER navigation
        // Since the UI is already gone, notifyListeners() won't affect the user
        clientProvider.clearData();
        adminProvider.clearData();
      }
    }
  }

// [UPDATE _buildSidebarLogoutButton in lib/Clientlayout.dart]
  Widget _buildSidebarLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _showLogoutConfirmation,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: ClientTheme.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ClientTheme.error.withOpacity(0.1)),
          ),
          child: const Row(
            children: [
              Icon(Iconsax.logout, color: ClientTheme.error, size: 20),
              SizedBox(width: 16),
              Text(
                "Logout",
                style: TextStyle(
                  color: ClientTheme.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// [UPDATE _buildLogoutButton for Desktop in lib/Clientlayout.dart]
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _showLogoutConfirmation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 12 : 20),
        padding: EdgeInsets.all(_isSidebarCollapsed ? 12 : 16),
        decoration: BoxDecoration(
          color: ClientTheme.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClientTheme.error.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.logout, color: ClientTheme.error, size: 20),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 12),
              const Text(
                "Logout",
                style: TextStyle(
                  color: ClientTheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

// [UPDATE in lib/Clientlayout.dart]
// [UPDATE in lib/Clientlayout.dart]
  Widget _buildMobileSidebar() {
    final provider = Provider.of<ClientProvider>(context);
    final selectedDevice = provider.selectedDeviceData;

    final String deviceName = selectedDevice?['DeviceName'] ?? 'No Device Selected';
    final String serialNumber = selectedDevice?['SerialNumber'] ?? 'N/A';
    final int channelsCount = selectedDevice?['ChannelsCount'] ?? 0;
    final String location = provider.selectedDeviceLocation;

    return IgnorePointer(
      ignoring: !_isSidebarOpen,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          double backgroundOpacity = _animationController.value.clamp(0.0, 1.0);
          return Stack(
            children: [
              GestureDetector(
                onTap: _toggleSidebar,
                child: Container(color: Colors.black.withOpacity(0.4 * backgroundOpacity)),
              ),
              Transform.translate(
                offset: Offset(_offsetAnimation.value - 260.0, 0),
                child: child,
              ),
            ],
          );
        },
        child: Container(
          width: 260,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: ClientTheme.background, // Light premium slate background
            borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // --- Premium Header Section ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ClientTheme.primaryColor.withOpacity(0.1), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: CircleAvatar(
                            radius: 33,
                            backgroundColor: ClientTheme.primaryColor.withOpacity(0.1),
                            backgroundImage: widget.userData['LogoPath']?.isNotEmpty == true
                                ? NetworkImage("$_imageBaseUrl${widget.userData['LogoPath']}")
                                : null,
                            child: widget.userData['LogoPath']?.isEmpty != false
                                ? const Icon(Iconsax.user, color: ClientTheme.primaryColor, size: 30)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.userData['DisplayName'] ?? 'Client User',
                        style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(
                          color: ClientTheme.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "VERIFIED CLIENT",
                        style: TextStyle(
                          color: ClientTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Menu Items ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildSidebarMenuItem(icon: Iconsax.home, label: "Home", screen: ClientScreen.devices),
                      _buildSidebarMenuItem(icon: Iconsax.setting_2, label: "Configure", screen: ClientScreen.configure),
                      _buildSidebarMenuItem(icon: Iconsax.profile_circle, label: "Account", screen: ClientScreen.settings),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        child: Divider(color: Colors.black12, thickness: 1),
                      ),

                      // Device Panel
                      _buildDeviceInfoPanel(deviceName, serialNumber, channelsCount, location),
                    ],
                  ),
                ),

                // --- Footer Logout ---
                _buildSidebarLogoutButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔑 UPDATED WIDGET: Mobile Device Info Panel with Location
// 🔑 UPDATED WIDGET: Mobile Device Info Panel with Device ID
  Widget _buildDeviceInfoPanel(String deviceName, String serialNumber, int channelsCount, String location) {
    final bool isDeviceSelected = deviceName != 'No Device Selected';
    final provider = Provider.of<ClientProvider>(context, listen: false);

    // Get the ID from provider
    final String deviceId = provider.selectedDeviceRecNo?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selected Device Status",
            style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(
              color: ClientTheme.textLight.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: isDeviceSelected ? () => _handleScreenSelection(ClientScreen.devices) : null,
            child: Row(
              children: [
                Icon(
                  isDeviceSelected ? Iconsax.cpu_charge : Iconsax.devices,
                  color: isDeviceSelected ? ClientTheme.success : ClientTheme.secondaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deviceName,
                    style: TextStyle(
                      color: isDeviceSelected ? Colors.black : ClientTheme.secondaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🆔 NEW: DEVICE ID ROW
                _buildInfoRow(
                  icon: Iconsax.key,
                  label: "Device ID:",
                  value: deviceId,
                  color: ClientTheme.primaryColor,
                ),
                const SizedBox(height: 8),

                _buildInfoRow(
                  icon: Iconsax.tag,
                  label: "Serial No:",
                  value: serialNumber,
                  color: ClientTheme.primaryColor,
                ),
                const SizedBox(height: 8),



                _buildInfoRow(
                  icon: Iconsax.global,
                  label: "Location:",
                  value: location,
                  color: Colors.orangeAccent,
                ),

                if (isDeviceSelected) ...[
                  const Divider(color: Colors.white30, height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      provider.clearSelection();
                      _toggleSidebar();
                    },
                    icon: const Icon(Iconsax.arrow_swap, size: 18),
                    label: const Text(
                      "Change Device",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClientTheme.error,
                      side: const BorderSide(color: ClientTheme.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size(double.infinity, 35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }
  Widget _buildInfoRow({required IconData icon, required String label, required String value, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }


  Widget _buildSidebarMenuItem({required IconData icon, required String label, required ClientScreen screen}) {
    final bool isActive = widget.activeScreen == screen;

    return GestureDetector(
      onTap: () {
        if (screen == ClientScreen.configure && Provider.of<ClientProvider>(context, listen: false).selectedDeviceRecNo == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a device first.")));
          return;
        }
        _handleScreenSelection(screen);
        _toggleSidebar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? ClientTheme.primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? ClientTheme.primaryColor : ClientTheme.textLight,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isActive ? ClientTheme.primaryColor : ClientTheme.textDark,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // =================================================================
  // === DESKTOP/SHARED WIDGETS ===
  // =================================================================

  Widget _buildDesktopSidebar() {
    final provider = Provider.of<ClientProvider>(context);
    final selectedDevice = provider.selectedDeviceData;

    final String deviceName = selectedDevice?['DeviceName'] ?? 'No Device Selected';
    final String serialNumber = selectedDevice?['SerialNumber'] ?? 'N/A';
    final int channelsCount = selectedDevice?['ChannelsCount'] ?? 0;

    // 🔑 NEW: Extract Location (Country) using Provider
    final String location = provider.selectedDeviceLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarCollapsed ? 80 : 260,
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClientTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ClientTheme.primaryColor.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildSidebarHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 12 : 20),
              children: [
                _buildMenuItem(icon: Iconsax.home, label: "Home", screen: ClientScreen.devices),
                const SizedBox(height: 8),
                _buildMenuItem(icon: Iconsax.setting_2, label: "Configure Channels", screen: ClientScreen.configure),
                const SizedBox(height: 8),
                _buildMenuItem(icon: Iconsax.profile_circle, label: "Settings", screen: ClientScreen.settings),
              ],
            ),
          ),

          if (!_isSidebarCollapsed)
          // 🔑 PASS LOCATION TO DESKTOP PANEL
            _buildDeviceInfoPanelWeb(deviceName, serialNumber, channelsCount, location),

          _buildLogoutButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 🔑 UPDATED WIDGET: Desktop Device Info Panel with Location
// 🔑 UPDATED WIDGET: Desktop Device Info Panel with Device ID
  Widget _buildDeviceInfoPanelWeb(String deviceName, String serialNumber, int channelsCount, String location) {
    final bool isDeviceSelected = deviceName != 'No Device Selected';
    final provider = Provider.of<ClientProvider>(context, listen: false);

    // Get the ID from provider
    final String deviceId = provider.selectedDeviceRecNo?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClientTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClientTheme.textLight.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selected Device",
              style: ClientTheme.themeData.textTheme.labelMedium?.copyWith(
                color: ClientTheme.textDark.withOpacity(0.7),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  isDeviceSelected ? Iconsax.cpu_charge : Iconsax.devices,
                  color: isDeviceSelected ? ClientTheme.primaryColor : ClientTheme.textLight,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deviceName,
                    style: ClientTheme.themeData.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ClientTheme.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // 🆔 UPDATED: DISPLAY DEVICE ID INSTEAD OF SERIAL IN FIRST COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Device ID",
                        style: ClientTheme.themeData.textTheme.labelSmall?.copyWith(color: ClientTheme.textLight, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        deviceId,
                        style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: ClientTheme.textDark),
                      ),
                    ],
                  ),
                ),

              ],
            ),
            Row(
              children: [
                Icon(Iconsax.global, size: 14, color: ClientTheme.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: ClientTheme.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (isDeviceSelected) ...[
              const Divider(height: 24, color: ClientTheme.textLight),
              OutlinedButton.icon(
                onPressed: provider.clearSelection,
                icon: const Icon(Iconsax.arrow_swap, size: 18),
                label: const Text(
                  "Change Device",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClientTheme.error,
                  side: const BorderSide(color: ClientTheme.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(double.infinity, 35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }
  Widget _buildMainContentArea(bool isMobile) {
    Widget content;
    final provider = Provider.of<ClientProvider>(context);

    if (widget.activeScreen == ClientScreen.devices && provider.selectedDeviceRecNo != null) {
      content = DeviceConfigScreen(key: deviceConfigScreenKey);
    }
    else if (widget.activeScreen == ClientScreen.configure && provider.selectedDeviceRecNo != null) {
      content = AllChannelConfigScreen(
        deviceRecNo: provider.selectedDeviceRecNo!,
        onSave: () {},
        allChannels: provider.channels,
      );
    }
    // 🆕 ROUTE TO DOWNLOADS
    else if (widget.activeScreen == ClientScreen.downloads) {
      content = const DownloadHistoryScreen();
    }
    else if (widget.activeScreen == ClientScreen.settings) {
      content = ClientSettingsScreen(userData: widget.userData);
    }
    else {
      content = widget.child;
    }

    return Column(
      children: [
        _buildTopHeader(isMobile),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: isMobile ? 10 : 0,
            ),
            child: content,
          ),
        ),
      ],
    );
  }
  Widget _buildTopHeader(bool isMobile) {
    final String clientName = widget.userData['DisplayName'] ?? 'Client';
    final String logoPath = widget.userData['LogoPath'] ?? '';

    final profileAvatar = CircleAvatar(
      radius: 20,
      backgroundColor: ClientTheme.background,
      backgroundImage: logoPath.isNotEmpty
          ? NetworkImage("$_imageBaseUrl$logoPath")
          : null,
      child: logoPath.isEmpty
          ? Icon(Iconsax.user, color: ClientTheme.textLight)
          : null,
    );


    if (isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: ClientTheme.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: ClientTheme.textDark.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.menu_close,
                    progress: _animationController,
                    color: _isSidebarOpen ? ClientTheme.primaryColor : ClientTheme.textDark,
                  ),
                  onPressed: _toggleSidebar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const _StyledLogoText(size: 24),

                Row(
                  children: [
                    // notificationIcon,
                    // const SizedBox(width: 12),
                    profileAvatar,
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final profileChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ClientTheme.surface,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 6),
            )
          ],
          border: Border.all(color: ClientTheme.background, width: 1),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clientName,
                  style: ClientTheme.themeData.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Verified Client",
                  style: TextStyle(fontSize: 10, color: ClientTheme.secondaryColor),
                ),
              ],
            ),
            const SizedBox(width: 12),
            profileAvatar,
          ],
        ),
      ).animate().fadeIn().slideX();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(widget.activeScreen),
                  style: ClientTheme.themeData.textTheme.displayMedium,
                ),
                Text(
                  _getSubtitle(widget.activeScreen),
                  style: ClientTheme.themeData.textTheme.bodyMedium,
                ),
              ],
            ),
            const Spacer(),
            // notificationIcon,
            // const SizedBox(width: 16),
            profileChip,
          ],
        ),
      );
    }
  }

  Widget _buildSidebarHeader() {
    return GestureDetector(
      onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(size: 40, useImage: true),

            if (!_isSidebarCollapsed) ...[
              Expanded(
                child: const _StyledLogoText(size: 28),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String label, required ClientScreen screen}) {
    final bool isActive = widget.activeScreen == screen;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (screen == ClientScreen.configure && Provider.of<ClientProvider>(context, listen: false).selectedDeviceRecNo == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a device first to configure channels.")));
            return;
          }
          // 🔴 UPDATED: Use middleware
          _handleScreenSelection(screen);
        },
        child: AnimatedContainer(
          duration: 200.ms,
          padding: EdgeInsets.all(_isSidebarCollapsed ? 12 : 16),
          decoration: BoxDecoration(
            color: isActive ? ClientTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive ? [
              BoxShadow(
                color: ClientTheme.primaryColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: _isSidebarCollapsed
              ? Center(
            child: AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: isActive ? Colors.white : ClientTheme.textLight, size: 22),
            ),
          )
              : Row(
            children: [
              AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(icon, color: isActive ? Colors.white : ClientTheme.textLight, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : ClientTheme.textDark,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  int _appScreenToNavIndex(ClientScreen screen) {
    if (screen == ClientScreen.devices) return 0;
    if (screen == ClientScreen.configure) return 1;
    if (screen == ClientScreen.settings) return 2;
    if (screen == ClientScreen.downloads) return 3; // 🆕 Added
    return -1;
  }

  ClientScreen _navIndexToAppScreen(int index) {
    switch (index) {
      case 0: return ClientScreen.devices;
      case 1: return ClientScreen.configure;
      case 2: return ClientScreen.settings;
      case 3: return ClientScreen.downloads; // 🆕 Added
      default: return ClientScreen.devices;
    }
  }


// [MODIFIED WIDGET in Clientlayout.dart]
  Widget _buildStartFab(BuildContext context) {
    return Hero(
      tag: 'wifi_setup_fab', // Unique tag for Hero animation
      child: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () {
            final provider = Provider.of<ClientProvider>(context, listen: false);

            // Validation: Ensure device is selected before showing setup
            if (provider.selectedDeviceRecNo == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PLEASE SELECT A DEVICE FIRST!"))
              );
              return;
            }

            // Trigger the beautiful expansion animation
            _showWifiSetupSheet(context);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ClientTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: ClientTheme.primaryColor.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: const Icon(Iconsax.flash_1, color: Colors.white, size: 30)
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1), curve: Curves.easeInOut)
                  .then(delay: 0.5.seconds)
                  .scale(duration: 1.seconds, begin: const Offset(1.1, 1.1), end: const Offset(1, 1), curve: Curves.easeInOut),
            ),
          ),
        ),
      ),
    );
  }

// Helper method to show the animated setup sheet
  void _showWifiSetupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows widget to take full height if needed
      backgroundColor: Colors.transparent, // Required for custom rounded corners
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9, // Opens at 90% screen height
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Handle bar for dragging
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // The actual WifiSetupWidget
              Expanded(
                child: WifiSetupWidget(
                  onConnected: () {
                    Navigator.pop(context); // Close sheet on success
                    // Optionally navigate to Home Overview
                    Provider.of<ClientProvider>(context, listen: false)
                        .goToChannelConfiguration();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
    final int currentIndex = _appScreenToNavIndex(widget.activeScreen);

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: ClientTheme.surface,
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // LEFT SIDE: Home & Config
              Row(
                children: [
                  _buildBottomNavItem(
                    context: context, icon: Iconsax.home, label: "Home", index: 0, currentIndex: currentIndex,
                    onTap: () => _handleScreenSelection(ClientScreen.devices), itemWidth: 0,
                  ),
                  const SizedBox(width: 20),
                  _buildBottomNavItem(
                    context: context, icon: Iconsax.setting_2, label: "Config", index: 1, currentIndex: currentIndex,
                    onTap: () {
                      if (Provider.of<ClientProvider>(context, listen: false).selectedDeviceRecNo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select device first.")));
                      } else {
                        _handleScreenSelection(ClientScreen.configure);
                      }
                    }, itemWidth: 0,
                  ),
                ],
              ),

              const SizedBox(width: 40), // Space for the FAB

              // RIGHT SIDE: Downloads & Settings
              Row(
                children: [
                  // 🆕 DOWNLOAD ICON (MOBILE ONLY)
                  _buildBottomNavItem(
                    context: context, icon: Iconsax.document_download, label: "Files", index: 3, currentIndex: currentIndex,
                    onTap: () => _handleScreenSelection(ClientScreen.downloads), itemWidth: 0,
                  ),
                  const SizedBox(width: 20),
                  _buildBottomNavItem(
                    context: context, icon: Iconsax.profile_circle, label: "Profile", index: 2, currentIndex: currentIndex,
                    onTap: () => _handleScreenSelection(ClientScreen.settings), itemWidth: 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context, required IconData icon, required String label, required int index, required int currentIndex,
    required VoidCallback onTap, required double itemWidth,
  }) {
    final bool isActive = index == currentIndex;
    final Color color = isActive ? ClientTheme.primaryColor : ClientTheme.textLight;

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Icon(icon, color: color, size: 24),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500),
            )
          ],
        ),
      ),
    );
  }

  String _getTitle(ClientScreen screen) {
    switch (screen) {
      case ClientScreen.devices: return "Home Overview";
      case ClientScreen.configure: return "Channel Configuration";
      case ClientScreen.settings: return "Account Settings";
      case ClientScreen.downloads: return "Download";
    }
  }

  String _getSubtitle(ClientScreen screen) {
    switch (screen) {
      case ClientScreen.devices: return "Quick view of selected device channels.";
      case ClientScreen.configure: return "Customize channel limits and appearance.";
      case ClientScreen.settings: return "Manage user and application preferences.";
      case ClientScreen.downloads:
        return "Manage Your Downloaded File";
    }
  }
}