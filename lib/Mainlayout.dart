// [REPLACE] lib/Mainlayout.dart

import 'dart:ui';
import 'package:countron_app/provider/admin_provider.dart';
import 'package:countron_app/provider/client_provider.dart';
import 'package:countron_app/provider/session_manager.dart'; // 🆕 IMPORTED
import 'package:countron_app/widgets/add_channel.dart';
import 'package:countron_app/widgets/successscreen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';

// Enum to identify the active screen
enum AppScreen {
  dashboard,
  clients,
  channels,
  settings,
}

// State management for sidebar
final ValueNotifier<bool> isSidebarCollapsed = ValueNotifier(true);

class MainLayout extends StatefulWidget {
  final Widget child;
  final AppScreen activeScreen;
  final Function(AppScreen) onScreenSelected;
  final VoidCallback onLogout;

  const MainLayout({
    super.key,
    required this.child,
    required this.activeScreen,
    required this.onScreenSelected,
    required this.onLogout,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // FAB animation state
  bool _isFabExpanded = false;

  // 🆕 NEW: Middleware to Save Session before notifying Parent
  void _handleScreenSelection(AppScreen screen) {
    // 1. Save the tab name to Session Storage
    // This ensures that if you reload, we know where you were.
    SessionManager.saveCurrentTab(screen.toString().split('.').last);

    // 2. Notify the parent widget to update the UI
    widget.onScreenSelected(screen);
  }

  // Helper to get the title for each screen
  String _getTitleForScreen(AppScreen screen) {
    switch (screen) {
      case AppScreen.dashboard:
        return 'Dashboard';
      case AppScreen.clients:
        return 'Manage Clients';
      case AppScreen.channels:
        return 'Manage Channels';
      case AppScreen.settings:
        return 'Settings';
    }
  }

  // Naye bottom bar ke liye index helper
  int _appScreenToNavIndex(AppScreen screen) {
    switch (screen) {
      case AppScreen.dashboard:
        return 0;
      case AppScreen.clients:
        return 1;
      case AppScreen.channels:
        return 2;
      case AppScreen.settings:
        return 3;
      default:
        return 0;
    }
  }

  // Naye bottom bar ke liye index helper
  AppScreen _navIndexToAppScreen(int index) {
    switch (index) {
      case 0:
        return AppScreen.dashboard;
      case 1:
        return AppScreen.clients;
      case 2:
        return AppScreen.channels;
      case 3:
        return AppScreen.settings;
      default:
        return AppScreen.dashboard;
    }
  }

  // === HELPER FUNCTION: Add Channel Dialog ===
  void _showReusableAddChannelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AddChannelDialog(
          onSave: (String newChannelName) {
            Navigator.pop(dialogContext);

            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SuccessScreen(
                message: "Channel '$newChannelName' Added Successfully!",
              ),
            ));

            if (widget.activeScreen == AppScreen.channels) {
              // Use the new handler here too for consistency
              _handleScreenSelection(AppScreen.channels);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700; // Mobile breakpoint
    final String title = _getTitleForScreen(widget.activeScreen);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,

      // === FLOATING ACTION BUTTON ===
      floatingActionButton: isMobile ? _buildMainFab(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // === BOTTOM APP BAR ===
      bottomNavigationBar: isMobile
          ? _buildBottomAppBar(context)
          : null, // Desktop par nahi dikhega

      body: SafeArea(
        child: Stack(
          children: [
            // --- 1. MAIN CONTENT ---
            ValueListenableBuilder<bool>(
              valueListenable: isSidebarCollapsed,
              builder: (context, isCollapsed, _) {
                final double sidebarWidth = isCollapsed ? 80 : 280;
                final double sidebarMargin = 16.0;
                final double contentGap = 16.0;

                final double mainContentLeft = isMobile
                    ? 0
                    : (sidebarWidth + sidebarMargin + contentGap);

                return Stack(
                  children: [
                    // === MAIN CONTENT AREA ===
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      left: mainContentLeft,
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Padding(
                            padding: EdgeInsets.all(
                              isMobile ? 12 : AppTheme.defaultPadding * 1.5,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // === HEADER ===
                                _Header(isMobile: isMobile, title: title),
                                SizedBox(
                                    height: isMobile
                                        ? 12
                                        : AppTheme.defaultPadding * 1.5),
                                // === PAGE CONTENT ===
                                Expanded(
                                  child: widget.child,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // === DESKTOP SIDEBAR ===
                    if (!isMobile)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        left: sidebarMargin,
                        top: sidebarMargin,
                        bottom: sidebarMargin,
                        width: sidebarWidth,
                        child: _ModernCollapsibleSidebar(
                          isCollapsed: isCollapsed,
                          activeScreen: widget.activeScreen,
                          onScreenSelected: _handleScreenSelection, // 🔴 UPDATED
                          onLogout: widget.onLogout,
                        ),
                      ),
                  ],
                );
              },
            ),

            // --- 2. ANIMATED FAB OPTIONS (Overlay) ---
            if (isMobile)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: _buildFabOptions(context),
              ),
          ],
        ),
      ),
    );
  }

  // "Plus" button
  Widget _buildMainFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
      backgroundColor: AppTheme.primaryBlue,
      elevation: 8,
      shape: const CircleBorder(),
      child: AnimatedRotation(
        turns: _isFabExpanded ? 0.375 : 0, // 135 degrees
        duration: const Duration(milliseconds: 300),
        child: Icon(
            _isFabExpanded ? Iconsax.close_square : Iconsax.add,
            color: Colors.white,
            size: 28),
      ),
    );
  }

  // "Add Client" / "Add Channel" options
  Widget _buildFabOptions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- Animated Options ---
        _StagedFabOption(
          icon: Iconsax.radar_2,
          label: 'Add Channel',
          color: AppTheme.accentPink,
          isExpanded: _isFabExpanded,
          delay: 100.ms,
          onTap: () {
            _showReusableAddChannelDialog(context);
            setState(() => _isFabExpanded = false);
          },
        ),
        const SizedBox(height: 16),
        _StagedFabOption(
          icon: Iconsax.profile_add,
          label: 'Add Client',
          color: AppTheme.accentPurple,
          isExpanded: _isFabExpanded,
          delay: 50.ms,
          onTap: () {
            print('Add Client Tapped');
            setState(() => _isFabExpanded = false);
          },
        ),
      ],
    );
  }

  // Staged FAB Option
  Widget _StagedFabOption({
    required IconData icon,
    required String label,
    required Color color,
    required bool isExpanded,
    required Duration delay,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Animate(
      target: isExpanded ? 1.0 : 0.0,
      effects: [
        SlideEffect(
            delay: delay,
            begin: const Offset(0.0, 1.0),
            duration: 250.ms,
            curve: Curves.easeOutCubic),
        FadeEffect(delay: delay, duration: 250.ms)
      ],
      child: GestureDetector(
        onTap: () {
          if (isExpanded) {
            onTap();
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Animate(
              target: isExpanded ? 1.0 : 0.0,
              effects: [
                SlideEffect(
                  delay: delay + 150.ms,
                  begin: const Offset(0.0, 0.5),
                  duration: 200.ms,
                  curve: Curves.easeOutCubic,
                ),
                FadeEffect(delay: delay + 150.ms, duration: 200.ms)
              ],
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom App Bar
  Widget _buildBottomAppBar(BuildContext context) {
    final int currentIndex = _appScreenToNavIndex(widget.activeScreen);

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppTheme.background,
      elevation: 10,
      shadowColor: AppTheme.shadowColor.withOpacity(0.2),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildBottomNavItem(
            context: context,
            icon: Iconsax.home,
            index: 0,
            currentIndex: currentIndex,
            onTap: () => _handleScreenSelection(_navIndexToAppScreen(0)), // 🔴 UPDATED
          ),
          _buildBottomNavItem(
            context: context,
            icon: Iconsax.profile_2user,
            index: 1,
            currentIndex: currentIndex,
            onTap: () => _handleScreenSelection(_navIndexToAppScreen(1)), // 🔴 UPDATED
          ),
          const SizedBox(width: 40), // FAB gap
          _buildBottomNavItem(
            context: context,
            icon: Iconsax.radar_2,
            index: 2,
            currentIndex: currentIndex,
            onTap: () => _handleScreenSelection(_navIndexToAppScreen(2)), // 🔴 UPDATED
          ),
          _buildBottomNavItem(
            context: context,
            icon: Iconsax.setting_2,
            index: 3,
            currentIndex: currentIndex,
            onTap: () => _handleScreenSelection(_navIndexToAppScreen(3)), // 🔴 UPDATED
          ),
        ],
      ),
    );
  }

  // Bottom Nav Item
  Widget _buildBottomNavItem({
    required BuildContext context,
    required IconData icon,
    required int index,
    required int currentIndex,
    required VoidCallback onTap,
  }) {
    final color = (index == currentIndex)
        ? AppTheme.primaryBlue
        : AppTheme.bodyText.withOpacity(0.8);

    return SizedBox(
      width: MediaQuery.of(context).size.width / 5.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

// ... [The rest of your Header and Sidebar classes remain exactly the same as you provided] ...
// Just ensure the _ModernCollapsibleSidebar uses the updated onTap logic below:

class _Header extends StatelessWidget {
  final bool isMobile;
  final String title;

  const _Header({
    required this.isMobile,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    String userName = 'Sachin Mishra';
    String userInitial = 'SM';

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isCompact = constraints.maxWidth < 750;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor,
                blurRadius: 40,
                offset: const Offset(0, 10),
                spreadRadius: -10,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: AppTheme.background.withOpacity(0.9),
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
                child: isMobile
                    ? _MobileHeaderContent(
                  userName: userName,
                  userInitial: userInitial,
                )
                    : _DesktopHeaderContent(
                  userName: userName,
                  userInitial: userInitial,
                  isCompact: isCompact,
                  title: title,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ... [Keep existing _MobileHeaderContent, _DesktopHeaderContent, etc.] ...
// ... [No changes needed in Header classes] ...
class _MobileHeaderContent extends StatelessWidget {
  final String userName;
  final String userInitial;

  const _MobileHeaderContent({
    required this.userName,
    required this.userInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _AppLogo(size: 34),
        const Spacer(),
        Row(
          children: [
            _HeaderNotificationButton(
              onPressed: () {},
              hasBadge: true,
            ),
            const SizedBox(width: 12),
            _MobileProfileAvatar(
              userInitial: userInitial,
              onPressed: () {},
            ),
          ],
        )
      ],
    );
  }
}

class _MobileProfileAvatar extends StatelessWidget {
  final String userInitial;
  final VoidCallback onPressed;

  const _MobileProfileAvatar(
      {required this.userInitial, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            userInitial,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// === DESKTOP HEADER ===
// =======================================================================
class _DesktopHeaderContent extends StatelessWidget {
  final String userName;
  final String userInitial;
  final bool isCompact;
  final String title;

  const _DesktopHeaderContent({
    required this.userName,
    required this.userInitial,
    required this.isCompact,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                // [MODIFIED] Using theme.headlineMedium for Bebas Neue
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primaryBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back, $userName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.bodyText.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(width: 28),
          Row(
            children: [
              _HeaderNotificationButton(
                onPressed: () {},
                hasBadge: true,
              ),
              const SizedBox(width: 16),
              _HeaderUserCard(
                userName: userName,
                userInitial: userInitial,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// =======================================================================
// === STYLED LOGO WIDGET (Bebas Neue + Multi-color) ===
// =======================================================================
class _StyledLogoText extends StatelessWidget {
  final double size;
  const _StyledLogoText({required this.size});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        // [MODIFIED] Using the theme's logoStyle
        style: GoogleFonts.greatVibes(
          textStyle: AppTheme.logoStyle.copyWith(
            fontSize: 50,
          ),
        ),

        children: [
          TextSpan(
            text: 'Count',
            style: TextStyle(color: AppTheme.primaryBlue), // Pehla color
          ),
          TextSpan(
            text: 'ron',
            style: TextStyle(color: AppTheme.accentPink), // Doosra color
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// === APP LOGO WIDGET ===
// =======================================================================
class _AppLogo extends StatelessWidget {
  final double size;
  const _AppLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return _StyledLogoText(size: size);
  }
}

// =======================================================================
// === HEADER HELPER WIDGETS (SOLID BUTTONS) ===
// =======================================================================
class _HeaderSolidButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final BoxShape shape;

  const _HeaderSolidButton({
    required this.child,
    required this.onPressed,
    this.padding = const EdgeInsets.all(10),
    this.shape = BoxShape.circle,
  });

  @override
  State<_HeaderSolidButton> createState() => _HeaderSolidButtonState();
}

class _HeaderSolidButtonState extends State<_HeaderSolidButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.lightGrey : AppTheme.background,
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(50), // for pill shape
            border: Border.all(
              color: _isHovered
                  ? AppTheme.borderGrey
                  : AppTheme.borderGrey.withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor.withOpacity(
                  _isHovered ? 0.3 : 0.2,
                ),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// --- Notification Button ---
class _HeaderNotificationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasBadge;

  const _HeaderNotificationButton({
    required this.onPressed,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HeaderSolidButton(
      onPressed: onPressed,
      child: Stack(
        children: [
          Icon(
            Iconsax.notification,
            size: 19,
            color: AppTheme.bodyText,
          ),
          if (hasBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- User Card (Pill shape) ---
class _HeaderUserCard extends StatelessWidget {
  final String userName;
  final String userInitial;

  const _HeaderUserCard({
    required this.userName,
    required this.userInitial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _HeaderSolidButton(
      onPressed: () {},
      shape: BoxShape.rectangle,
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color:
                  AppTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userInitial,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.darkText, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme
                          .accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppTheme.accentGreen, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernCollapsibleSidebar extends StatelessWidget {
  final bool isCollapsed;
  final AppScreen activeScreen;
  final Function(AppScreen) onScreenSelected;
  final VoidCallback onLogout;

  const _ModernCollapsibleSidebar({
    required this.isCollapsed,
    required this.activeScreen,
    required this.onScreenSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkText.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Header Section
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(isCollapsed ? 16 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.cpu,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _StyledLogoText(size: 36),
                  ),
                ],
              ],
            ),
          ),

          // Toggle button
          GestureDetector(
            onTap: () => isSidebarCollapsed.value = !isSidebarCollapsed.value,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 16 : 24, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Center(
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: isCollapsed ? 0.5 : 0,
                    child: Icon(
                      Iconsax.arrow_left_2,
                      size: 20,
                      color: AppTheme.bodyText,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // === MENU ===
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
              child: Column(
                children: [
                  _CollapsibleMenuItem(
                    icon: Iconsax.home,
                    text: 'Dashboard',
                    isActive: activeScreen == AppScreen.dashboard,
                    isCollapsed: isCollapsed,
                    onTap: () => onScreenSelected(AppScreen.dashboard), // 🔴 SAVES AUTOMATICALLY via Wrapper
                  ),
                  _CollapsibleMenuItem(
                    icon: Iconsax.profile_2user,
                    text: 'Clients',
                    isActive: activeScreen == AppScreen.clients,
                    isCollapsed: isCollapsed,
                    onTap: () => onScreenSelected(AppScreen.clients),
                  ),
                  _CollapsibleMenuItem(
                    icon: Iconsax.radar_2,
                    text: 'Channels',
                    isActive: activeScreen == AppScreen.channels,
                    isCollapsed: isCollapsed,
                    onTap: () => onScreenSelected(AppScreen.channels),
                  ),
                  const Spacer(),
                  if (!isCollapsed) ...[
                    const Divider(color: AppTheme.borderGrey),
                    const SizedBox(height: 8),
                  ],
                  _CollapsibleMenuItem(
                    icon: Iconsax.setting_2,
                    text: 'Settings',
                    isActive: activeScreen == AppScreen.settings,
                    isCollapsed: isCollapsed,
                    onTap: () => onScreenSelected(AppScreen.settings),
                  ),
                  _CollapsibleMenuItem(
                    icon: Iconsax.logout,
                    text: 'Logout',
                    isCollapsed: isCollapsed,
                    textColor: Colors.red.shade400,
                    iconColor: Colors.red.shade400,
                    onTap: () async {
                      // [UPDATE] Clear Providers explicitly here
                      Provider.of<AdminProvider>(context, listen: false).clearData();
                      Provider.of<ClientProvider>(context, listen: false).clearData(); // Clear client data too
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();

                      // Trigger the original logout callback (navigation)
                      onLogout();
                    },
                  ),
                  SizedBox(height: isCollapsed ? 16 : 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ... [Keep _CollapsibleMenuItem and _CollapsibleMenuItemState exactly as they were] ...
class _CollapsibleMenuItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  const _CollapsibleMenuItem({
    required this.icon,
    required this.text,
    this.isActive = false,
    required this.isCollapsed,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  _CollapsibleMenuItemState createState() => _CollapsibleMenuItemState();
}

class _CollapsibleMenuItemState extends State<_CollapsibleMenuItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = widget.textColor ??
        (widget.isActive ? AppTheme.primaryBlue : AppTheme.bodyText);
    final effectiveIconColor = widget.iconColor ??
        (widget.isActive ? AppTheme.primaryBlue : AppTheme.bodyText);

    Widget menuItem = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) => _animationController.reverse(),
        onTapCancel: () => _animationController.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: EdgeInsets.all(widget.isCollapsed ? 12 : 16),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? AppTheme.primaryBlue.withOpacity(0.1)
                      : (_isHovered
                      ? AppTheme.borderGrey.withOpacity(0.5)
                      : Colors.transparent),
                  borderRadius:
                  BorderRadius.circular(widget.isCollapsed ? 12 : 16),
                  border: widget.isActive
                      ? Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2))
                      : null,
                ),
                child: widget.isCollapsed
                    ? Center(
                  child: Icon(
                    widget.icon,
                    color: effectiveIconColor,
                    size: 20,
                  ),
                )
                    : Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: effectiveIconColor,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: effectiveTextColor,
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Tooltip(
        message: widget.text,
        preferBelow: false,
        verticalOffset: 0,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontSize: 12,
        ),
        child: menuItem,
      );
    }

    return menuItem;
  }
}