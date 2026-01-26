import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../Clientlayout.dart';
import '../provider/client_provider.dart';
import '../theme/client_theme.dart';
import '../widgets/constants.dart';
// Removed: import 'ClientShell.dart'; // No longer needed here

// === HOVER WRAPPER FOR SELECT BUTTON (Unchanged) ===
class _SelectButtonWithHover extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isOnline;

  const _SelectButtonWithHover({
    required this.onPressed,
    required this.isOnline,
  });

  @override
  State<_SelectButtonWithHover> createState() => _SelectButtonWithHoverState();
}

class _SelectButtonWithHoverState extends State<_SelectButtonWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          height: 40,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: ClientTheme.primaryColor,
              elevation: _isHovering ? 8 : 0,
              shadowColor: ClientTheme.primaryColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: 200.ms,
                  transform: Matrix4.translationValues(_isHovering ? 4 : 0, 0, 0),
                  child: const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  "Select Device",
                  style: ClientTheme.themeData.textTheme.labelLarge?.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// === DEVICE SELECTION SCREEN (MODIFIED TO BE STANDALONE) ===
// =======================================================================

class DeviceSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onDeviceSelected;

  const DeviceSelectionScreen({
    super.key,
    required this.userData,
    required this.onDeviceSelected, // Require the callback
  });

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  List<dynamic> _devices = [];
  bool _isLoading = true;
  String? _error;
  static const String _imageBaseUrl = "https://storage.googleapis.com/upload-images-34/images/LMS/";
  final Set<int> _unblurredIndices = {};

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  // === API FETCH LOGIC (Unchanged) ===
  Future<void> _fetchDevices() async {
    try {
      String baseUrl ='{$ApiConstants.baseUrl}/client_api.php';
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "GET_DEVICES",
          "ClientRecNo": widget.userData['UserID'] ?? widget.userData['RecNo'],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted && result['status'] == 'success') {
          setState(() {
            _devices = result['data'];
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _error = result['error'] ?? "No devices found.";
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _error = "Server Error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Connection failed. Please check internet.";
          _isLoading = false;
        });
      }
    }
  }

  // === MODIFIED NAVIGATION LOGIC ===
  void _onDeviceSelected(Map<String, dynamic> device) {
    debugPrint("--- ON DEVICE SELECTED: Button pressed for ${device['DeviceName']}. ---");

    // 🔑 CALL THE CALLBACK: This tells the ClientShell (parent) to change the screen
    widget.onDeviceSelected(device);

    debugPrint("--- ON DEVICE SELECTED: Callback complete. Screen should swap. ---");
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("DeviceSelectionScreen: Building...");
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final horizontalPadding = isMobile ? 20.0 : 40.0;

    // 🔑 STANDALONE FIX: Wrap the entire content in a Scaffold
    return Scaffold(
      backgroundColor: ClientTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFrostedHeader(isMobile),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isMobile ? 20 : 30),
                  Text(
                    "Choose Your Device",
                    style: ClientTheme.themeData.textTheme.displayLarge?.copyWith(
                      color: ClientTheme.textDark,
                      fontSize: isMobile ? 28 : 34,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 10),
                  Text(
                    "Your gateway to real-time monitoring and analytics.",
                    style: ClientTheme.themeData.textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 14 : 15),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
                  SizedBox(height: isMobile ? 30 : 40),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedHeader(bool isMobile) {
    // ... Frosted Header implementation (Unchanged)
    final String clientName = widget.userData['DisplayName'] ?? 'Client';
    final String logoPath = widget.userData['LogoPath'] ?? '';

    final logoWidget = RichText(
      text: TextSpan(
        style: GoogleFonts.greatVibes(
          fontSize: isMobile ? 40 : 50,
          fontWeight: FontWeight.normal,
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

    final profileChip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMobile)
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    clientName,
                    style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(fontSize: 18, color: ClientTheme.textDark),
                  ),
                  Text(
                    "Client Portal",
                    style: TextStyle(
                        color: ClientTheme.primaryColor.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
          ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ClientTheme.primaryColor.withOpacity(0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: isMobile ? 20 : 24,
            backgroundColor: Colors.white,
            backgroundImage: logoPath.isNotEmpty
                ? NetworkImage("$_imageBaseUrl$logoPath")
                : null,
            child: logoPath.isEmpty
                ? const Icon(Iconsax.user, color: ClientTheme.textLight)
                : null,
          ),
        ),
      ],
    );

    return Container(
      margin: EdgeInsets.fromLTRB(isMobile ? 12 : 30, isMobile ? 12 : 20, isMobile ? 12 : 30, 0),
      decoration: BoxDecoration(
        color: ClientTheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -10,
          ),
        ],
        border: Border.all(
          color: ClientTheme.surface.withOpacity(0.9),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 12 : 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                logoWidget,
                profileChip,
              ],
            ).animate().fadeIn(duration: 500.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // ... Content implementation (Unchanged)
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: ClientTheme.primaryColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.wifi_square, size: 60, color: ClientTheme.error.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text("Connection Error", style: ClientTheme.themeData.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: ClientTheme.textLight)),
            TextButton(
              onPressed: _fetchDevices,
              child: const Text("Retry", style: TextStyle(color: ClientTheme.primaryColor)),
            )
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.box, size: 60, color: ClientTheme.textLight.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("No Devices Found", style: ClientTheme.themeData.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("It looks like no devices are assigned to your account yet.", style: TextStyle(color: ClientTheme.textLight)),
          ],
        ),
      );
    }

    // Responsive Grid
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 700 ? 3 : (width > 500 ? 2 : 1);
    final double cardAspectRatio = width > 700 ? 1.5 : 1.1;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 25,
        mainAxisSpacing: 25,
        childAspectRatio: cardAspectRatio,
      ),
      itemCount: _devices.length,
      itemBuilder: (context, index) => _buildDeviceCard(_devices[index], index),
    );
  }

  // --- MODIFIED DEVICE CARD (Unchanged) ---
  Widget _buildDeviceCard(Map<String, dynamic> device, int index) {
    final bool isOnline = device['Status'] == 'Online';
    final String name = device['DeviceName'] ?? 'Unknown Device';
    final String location = device['Location'] ?? 'Unknown Location';
    final String serialNumber = device['SerialNumber'] ?? 'SN-N/A';

    final bool isBlurred = !_unblurredIndices.contains(index);
    final Color statusColor = isOnline ? ClientTheme.success : ClientTheme.textLight;
    final Color cardColor = isOnline ? ClientTheme.surface : ClientTheme.background.withOpacity(0.8);
    final TextStyle baseTextStyle = ClientTheme.themeData.textTheme.bodyMedium!.copyWith(
      color: ClientTheme.textDark,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: 300.ms,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: ClientTheme.textDark.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isOnline ? ClientTheme.primaryColor.withOpacity(0.1) : ClientTheme.textLight.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distributes space vertically
            children: [
              // 1. HEADER: Icon and Name on the same row, Location below. (Dot removed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Icon and Name (Requested change)
                  Row(
                    children: [
                      // Icon Container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.cpu_charge,
                          color: statusColor,
                          size: 20, // Slightly smaller icon
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Device Name (Expanded to fill remaining horizontal space)
                      Expanded(
                        child: Text(
                          name,
                          style: ClientTheme.themeData.textTheme.titleLarge?.copyWith(fontSize: 20, color: ClientTheme.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Removed Status Dot
                    ],
                  ),

                  const SizedBox(height: 8), // Space between Name/Icon and Location

                  // Row 2: Location (Subtitle)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        Icon(Iconsax.location, size: 14, color: ClientTheme.textLight), // Smaller location icon
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(color: ClientTheme.textLight, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. Serial Number, Actions, and Select Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ADDED SERIAL NUMBER LABEL HERE
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      "Serial No:",
                      style: ClientTheme.themeData.textTheme.labelSmall?.copyWith(
                        color: ClientTheme.textLight,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  // Serial Number & Toggle Button
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ClientTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Serial Number (FIXED BLUR)
                        Flexible(
                          child: Text(
                            serialNumber,
                            style: isBlurred
                                ? baseTextStyle.copyWith(
                              color: Colors.transparent, // Make text invisible
                              shadows: [
                                Shadow(
                                  blurRadius: 5.0, // High blur radius for visible blur effect
                                  color: ClientTheme.textDark.withOpacity(0.8), // Shadow color replaces text
                                  offset: Offset(0, 0),
                                ),
                              ],
                            )
                                : baseTextStyle,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Action Button (Unblur)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_unblurredIndices.contains(index)) {
                                _unblurredIndices.remove(index);
                              } else {
                                _unblurredIndices.add(index);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: 200.ms,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isBlurred ? ClientTheme.primaryColor : ClientTheme.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isBlurred ? Iconsax.eye : Iconsax.eye_slash,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Select Button (Now uses the hover wrapper)
                  _SelectButtonWithHover(
                    onPressed: () => _onDeviceSelected(device),
                    isOnline: isOnline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate(delay: (index * 100).ms).fadeIn().scale(begin: const Offset(0.95, 0.95)),

    );
  }
}