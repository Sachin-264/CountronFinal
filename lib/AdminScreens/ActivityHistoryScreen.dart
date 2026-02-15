// lib/AdminScreens/activity_history_screen.dart

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentClients;
  final List<Map<String, dynamic>> recentDevices;

  const ActivityHistoryScreen({
    super.key,
    required this.recentClients,
    required this.recentDevices,
  });

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  List<Map<String, dynamic>> _processActivities() {
    List<Map<String, dynamic>> activities = [];

    // Process Clients
    for (var client in widget.recentClients) {
      activities.add({
        'type': 'client',
        'title': 'New client onboarded',
        'name': client['CompanyName'] ?? 'Unknown Client',
        'date': DateTime.parse(client['CreatedAt'] ?? DateTime.now().toString()),
        'icon': Iconsax.building,
        'color': AppTheme.accentGreen,
      });
    }

    // Process Devices
    for (var device in widget.recentDevices) {
      activities.add({
        'type': 'device',
        'title': 'New device registered',
        'name': device['DeviceName'] ?? 'Unknown Device',
        'date': DateTime.parse(device['CreatedAt'] ?? DateTime.now().toString()),
        'icon': Iconsax.flash_1,
        'color': AppTheme.accentBlue,
      });
    }

    // Sort by date newest first
    activities.sort((a, b) => b['date'].compareTo(a['date']));

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      activities = activities.where((a) =>
      a['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return activities;
  }

  @override
  Widget build(BuildContext context) {
    final activities = _processActivities();

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryBlue,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Activity History',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryBlue, AppTheme.accentPurple],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or action...',
                      prefixIcon: const Icon(Iconsax.search_normal_1, color: AppTheme.bodyText),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Filter Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.bodyText,
                    indicatorColor: AppTheme.primaryBlue,
                    onTap: (index) => setState(() {}),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Clients'),
                      Tab(text: 'Devices'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildActivityList(activities),
        ],
      ),
    );
  }

  Widget _buildActivityList(List<Map<String, dynamic>> allActivities) {
    // Filter by tab index
    final filtered = allActivities.where((a) {
      if (_tabController.index == 1) return a['type'] == 'client';
      if (_tabController.index == 2) return a['type'] == 'device';
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.ghost, size: 64, color: AppTheme.bodyText.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('No activities found', style: TextStyle(color: AppTheme.bodyText)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final item = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ActivityTile(item: item),
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
                ),
                Text(
                  item['title'] as String,
                  style: const TextStyle(color: AppTheme.bodyText, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${(item['date'] as DateTime).day}/${(item['date'] as DateTime).month}",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Text(
                "${(item['date'] as DateTime).hour}:${(item['date'] as DateTime).minute.toString().padLeft(2, '0')}",
                style: const TextStyle(color: AppTheme.bodyText, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}