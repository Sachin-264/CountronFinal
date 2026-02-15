// [REPLACE] lib/AdminScreens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../AdminService/dashboard_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_channel.dart';
import '../widgets/add_client_dialog.dart';
import '../widgets/successscreen.dart';
import 'ActivityHistoryScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  bool _isFabExpanded = false;
  bool _isLoading = true;

  // Dashboard data
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _recentClients = [];
  List<Map<String, dynamic>> _recentDevices = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Get actual admin RecNo from logged-in user
      final int adminRecNo = 12; // Replace with actual admin RecNo

      final data = await _apiService.getDashboardData(adminRecNo);

      setState(() {
        _statistics = data['statistics'];
        _recentClients = List<Map<String, dynamic>>.from(data['recent_clients'] ?? []);
        _recentDevices = List<Map<String, dynamic>>.from(data['recent_devices'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _showReusableAddChannelDialog(BuildContext context) {
    setState(() => _isFabExpanded = false);
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
            _loadDashboardData(); // Refresh data
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            isDesktop ? 32 : 16,
            isDesktop ? 32 : 16,
            isDesktop ? 32 : 90,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(context, isDesktop)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideX(begin: -0.1, curve: Curves.easeOut),
              const SizedBox(height: 32),
              DashboardCards(
                isDesktop: isDesktop,
                statistics: _statistics,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 32),
              _buildRecentActivity(context, isDesktop)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms),
            ],
          ),
        ),
        if (isDesktop) _buildAnimatedFab(context),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, Admin 👋',
          style: isDesktop
              ? theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold, color: AppTheme.darkText)
              : theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold, color: AppTheme.darkText),
        ),
        const SizedBox(height: 8),
        Text(
          'Here\'s what\'s happening with your smart loggers today.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.bodyText,
            fontSize: isDesktop ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);

    // Combine recent clients and devices into activities
    List<Map<String, dynamic>> activities = [];

    // Add recent clients
    for (var client in _recentClients) {
      activities.add({
        'title': 'New client added',
        'subtitle': client['CompanyName'] ?? 'Unknown',
        'time': _formatTime(client['CreatedAt']),
        'icon': Iconsax.building,
        'color': AppTheme.accentGreen,
      });
    }

    // Add recent devices
    for (var device in _recentDevices) {
      activities.add({
        'title': 'New device connected',
        'subtitle': device['DeviceName'] ?? 'Unknown',
        'time': _formatTime(device['CreatedAt']),
        'icon': Iconsax.flash_1,
        'color': AppTheme.accentBlue,
      });
    }

    // Sort by time (newest first) and take top 5
    activities = activities.take(5).toList();

    if (activities.isEmpty) {
      activities = [
        {'title': 'No recent activity', 'subtitle': 'Start by adding clients and devices', 'time': 'Now', 'icon': Iconsax.info_circle, 'color': AppTheme.bodyText},
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge,
              ),
              // Inside Widget _buildRecentActivity in home_screen.dart

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityHistoryScreen(
                        recentClients: _recentClients,
                        recentDevices: _recentDevices,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => Divider(
              height: 24,
              thickness: 1,
              color: AppTheme.borderGrey.withOpacity(0.7),
            ),
            itemBuilder: (context, index) => _buildActivityItem(context, activities[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final color = activity['color'] as Color;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(activity['icon'] as IconData, color: color, size: 24),
      ),
      title: Text(
          activity['title'] as String,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600)
      ),
      subtitle: Text(
          activity['subtitle'] as String,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.bodyText, fontSize: 13)
      ),
      trailing: Text(
          activity['time'] as String,
          style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.bodyText)
      ),
    );
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildAnimatedFab(BuildContext context) {
    return Positioned(
      bottom: 32,
      right: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _StagedFabOption(
            icon: Iconsax.radar_2,
            label: 'Add Channel',
            color: AppTheme.accentPink,
            isExpanded: _isFabExpanded,
            delay: 100.ms,
            onTap: () {
              _showReusableAddChannelDialog(context);
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
              setState(() => _isFabExpanded = false); // Close FAB menu
              _showAddClientDialog(context); // Open Add Client Dialog
            },
          ),
          const SizedBox(height: 24),
          FloatingActionButton(
            onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
            backgroundColor: AppTheme.primaryBlue,
            elevation: 8,
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.375 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                  _isFabExpanded ? Iconsax.close_square : Iconsax.add,
                  color: Colors.white,
                  size: 28
              ),
            ),
          ).animate().scale(delay: 500.ms, duration: 300.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }



  void _showAddClientDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AddClientScreen(
          onSave: (String clientName) {
            // Close the dialog
            Navigator.pop(dialogContext);

            // Show success screen
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SuccessScreen(
                message: "Client '$clientName' Added Successfully!",
              ),
            ));

            // Refresh dashboard data
            _loadDashboardData();
          },
        );
      },
    );
  }


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
            curve: Curves.easeOutCubic
        ),
        FadeEffect(delay: delay, duration: 250.ms)
      ],
      child: GestureDetector(
        onTap: () {
          if (isExpanded) {
            onTap();
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Animate(
              target: isExpanded ? 1.0 : 0.0,
              effects: [
                SlideEffect(
                  delay: delay + 150.ms,
                  begin: const Offset(-0.5, 0.0),
                  duration: 200.ms,
                  curve: Curves.easeOutCubic,
                ),
                FadeEffect(delay: delay + 150.ms, duration: 200.ms)
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
}

// Dashboard Cards with Real Data
class DashboardCards extends StatelessWidget {
  final bool isDesktop;
  final Map<String, dynamic>? statistics;

  const DashboardCards({
    super.key,
    required this.isDesktop,
    this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final stats = statistics ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = isDesktop ? 4 : 1;
        double spacing = isDesktop ? 24 : 16;
        double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
        double itemHeight = isDesktop ? 160 : 150;
        double aspectRatio = itemWidth / itemHeight;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
          children: [
            _StatCard(
                title: 'Total Clients',
                value: stats['TotalClients']?.toString() ?? '0',
                change: '+${stats['NewClients'] ?? 0}',
                isPositive: true,
                icon: Iconsax.profile_2user,
                color: AppTheme.primaryBlue,
                isDesktop: isDesktop
            ),
            _StatCard(
                title: 'Active Devices',
                value: stats['ActiveDevices']?.toString() ?? '0',
                change: '+${stats['NewDevices'] ?? 0}',
                isPositive: true,
                icon: Iconsax.cpu,
                color: AppTheme.accentPurple,
                isDesktop: isDesktop
            ),
            _StatCard(
                title: 'Total Channels',
                value: stats['TotalChannels']?.toString() ?? '0',
                change: '+${stats['NewChannels'] ?? 0}',
                isPositive: true,
                icon: Iconsax.radar_2,
                color: AppTheme.accentPink,
                isDesktop: isDesktop
            ),
            _StatCard(
                title: 'Active Clients',
                value: stats['ActiveClients']?.toString() ?? '0',
                change: '${stats['ActiveClients'] ?? 0}',
                isPositive: true,
                icon: Iconsax.tick_circle,
                color: AppTheme.accentGreen,
                isDesktop: isDesktop
            ),
          ],
        );
      },
    );
  }
}

// StatCard remains the same as before
class _StatCard extends StatefulWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;
  final bool isDesktop;

  const _StatCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
    required this.isDesktop,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.color.withOpacity(_isHovered ? 0.5 : 0.1),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            if (_isHovered)
              BoxShadow(
                color: widget.color.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: -5,
              ),
          ],
        ),
        child: widget.isDesktop
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.bodyText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildChangeIndicator(theme),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            _buildChangeIndicator(theme),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.bodyText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChangeIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (widget.isPositive ? AppTheme.accentGreen : AppTheme.accentRed).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
            size: 14,
            color: widget.isPositive ? AppTheme.accentGreen : AppTheme.accentRed,
          ),
          const SizedBox(width: 4),
          Text(
            widget.change,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.isPositive ? AppTheme.accentGreen : AppTheme.accentRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
