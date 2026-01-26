// [UPDATE] lib/AdminScreens/ClientScreen/ClientScreen.dart

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../AdminService/client_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/add_client_dialog.dart';
import 'Widget/edit_client_dialog.dart';
import '../../widgets/orbit_loader.dart';
import 'Widget/reset_password_dialog_dart.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen>
    with SingleTickerProviderStateMixin {
  final ClientApiService _apiService = ClientApiService();
  final TextEditingController _searchController = TextEditingController();

  TabController? _tabController;
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _activeClients = [];
  List<Map<String, dynamic>> _inactiveClients = [];
  List<Map<String, dynamic>> _filteredClients = [];

  bool _isLoading = true;
  String _searchQuery = '';

  static const String _imageBaseUrl =
      "https://storage.googleapis.com/upload-images-34/images/LMS/";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClients();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  Future<void> _loadClients() async {
    print('DEBUG: Starting client load process...');
    setState(() => _isLoading = true);

    try {
      final clients = await _apiService.getAllClients();

      setState(() {
        _allClients = clients;
        _activeClients = clients.where((c) => c['IsActive'] == 1).toList();
        _inactiveClients = clients.where((c) => c['IsActive'] == 0).toList();
        _applyFilters();
        _isLoading = false;
      });
      print('DEBUG: Client lists updated successfully.');
    } catch (e) {
      print('ERROR: Failed to load clients: $e');
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to load clients: $e');
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> sourceList;
    switch (_tabController?.index ?? 0) {
      case 0:
        sourceList = _activeClients;
        break;
      case 1:
        sourceList = _inactiveClients;
        break;
      default:
        sourceList = _activeClients;
    }

    if (_searchQuery.isEmpty) {
      _filteredClients = List.from(sourceList);
    } else {
      _filteredClients = sourceList.where((client) {
        final companyName = (client['CompanyName'] ?? '').toLowerCase();
        final email = (client['ContactEmail'] ?? '').toLowerCase();
        final username = (client['Username'] ?? '').toLowerCase();
        return companyName.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            username.contains(_searchQuery);
      }).toList();
    }
  }

  Widget _buildClientLogo(String? logoPath) {
    if (logoPath == null || logoPath.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withOpacity(0.2),
              AppTheme.primaryBlue.withOpacity(0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Iconsax.building, color: AppTheme.primaryBlue, size: 24),
      );
    }

    final String imageUrl = _imageBaseUrl + logoPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.2),
                  AppTheme.primaryBlue.withOpacity(0.1)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
            Icon(Iconsax.building, color: AppTheme.primaryBlue, size: 24),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);

    // Make sure 'return' is here!
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading)
              Expanded(
                child: Center(child: OrbitLoader()),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    _buildSearchAndTabs(theme, isMobile),

                    // Logic to show Empty State OR List
                    if (_allClients.isEmpty)
                      _buildEmptyState()
                    else
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildClientList(isMobile),
                            _buildClientList(isMobile),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndTabs(ThemeData theme, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search clients...',
                      hintStyle:
                      TextStyle(color: AppTheme.bodyText.withOpacity(0.5)),
                      prefixIcon: Icon(Iconsax.search_normal_1,
                          color: AppTheme.primaryBlue, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Iconsax.close_circle,
                            color: AppTheme.bodyText, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                          : null,
                      filled: true,
                      fillColor: AppTheme.lightGrey.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                        BorderSide(color: AppTheme.primaryBlue, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showAddClientDialog,
                  icon: const Icon(Iconsax.add, size: 20),
                  label: Text(
                    isMobile ? 'ADD' : 'ADD CLIENT',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24, 0, isMobile ? 16 : 24, 16),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() => _applyFilters()),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.darkText,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8)
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              indicatorPadding: const EdgeInsets.all(6),
              labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.tick_circle, size: 18),
                      const SizedBox(width: 8),
                      Text('Active (${_activeClients.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.close_circle, size: 18),
                      const SizedBox(width: 8),
                      Text('Inactive (${_inactiveClients.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientList(bool isMobile) {
    if (_filteredClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.search_normal,
                size: 64, color: AppTheme.bodyText.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No clients found' : 'No matching clients',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.bodyText,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.bodyText.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredClients.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildMobileCard(_filteredClients[index], index),
          );
        },
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ListView.builder(
        itemCount: _filteredClients.length,
        itemBuilder: (context, index) {
          return _buildDesktopRow(_filteredClients[index], index);
        },
      ),
    );
  }

  Widget _buildDesktopRow(Map<String, dynamic> client, int index) {
    final theme = Theme.of(context);
    final bool isActive = client['IsActive'] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: InkWell(
        onTap: () => _editClient(client),
        borderRadius: BorderRadius.circular(16),
        hoverColor: AppTheme.primaryBlue.withOpacity(0.02),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _buildClientLogo(client['LogoPath']),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['CompanyName'] ?? 'N/A',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Iconsax.sms, size: 14, color: AppTheme.bodyText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            client['ContactEmail'] ?? '-',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.bodyText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // REMOVED: Password Row (as requested)
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildStatusTag(isActive),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildActionButtonWithLabel(
                    icon: Iconsax.edit_2,
                    label: 'Edit',
                    color: AppTheme.accentPurple,
                    onTap: () => _editClient(client),
                  ),
                  _buildActionButtonWithLabel(
                    icon: Iconsax.key,
                    label: 'Password',
                    color: AppTheme.accentYellow,
                    onTap: () => _resetPassword(client),
                  ),
                  _buildActionButtonWithLabel(
                    icon: isActive ? Iconsax.eye_slash : Iconsax.eye,
                    label: isActive ? 'Disable' : 'Enable',
                    color: isActive ? AppTheme.accentRed : AppTheme.accentGreen,
                    onTap: () => _toggleClientStatus(client),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (30 * index).ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionButtonWithLabel({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> client, int index) {
    final theme = Theme.of(context);
    final bool isActive = client['IsActive'] == 1;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildClientLogo(client['LogoPath']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client['CompanyName'] ?? 'N/A',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusTag(isActive),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Iconsax.sms, size: 14, color: AppTheme.bodyText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        client['ContactEmail'] ?? 'No email',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.darkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // REMOVED: Password Row (as requested)
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderGrey.withOpacity(0.5)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMobileActionButton(
                  context,
                  icon: Iconsax.edit,
                  text: 'Edit',
                  color: AppTheme.accentPurple,
                  onTap: () => _editClient(client),
                ),
                _buildMobileActionButton(
                  context,
                  icon: Iconsax.key,
                  text: 'Pass',
                  color: AppTheme.accentYellow,
                  onTap: () => _resetPassword(client),
                ),
                _buildMobileActionButton(
                  context,
                  icon: isActive ? Iconsax.eye_slash : Iconsax.eye,
                  text: isActive ? 'Disable' : 'Enable',
                  color: isActive ? AppTheme.bodyText : AppTheme.accentGreen,
                  onTap: () => _toggleClientStatus(client),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (50 * index).ms)
        .slideX(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildStatusTag(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.accentGreen.withOpacity(0.15)
            : AppTheme.bodyText.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppTheme.accentGreen.withOpacity(0.3)
              : AppTheme.bodyText.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accentGreen : AppTheme.bodyText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppTheme.accentGreen : AppTheme.bodyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionButton(
      BuildContext context, {
        required IconData icon,
        required String text,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie.asset(
            //   'assets/animations/empty.json',
            //   width: 200,
            //   height: 200,
            // ),
            const SizedBox(height: 24),
            Text(
              'No Clients Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first client to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClientDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddClientScreen(),
    ).then((_) => _loadClients());
  }

  // === UPDATED: _editClient to pass password ===
  void _editClient(Map<String, dynamic> client) {
    bool isMobile = MediaQuery.of(context).size.width < 900;

    // IMPORTANT: EditClientDialog constructor updated to accept currentPassword
    if (isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditClientDialog(
            client: client,
            currentPassword: client['Password'], // Explicitly pass password
            onSave: _loadClients,
            initialTabIndex: 0,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => EditClientDialog(
          client: client,
          currentPassword: client['Password'], // Explicitly pass password
          onSave: _loadClients,
          initialTabIndex: 0,
        ),
      );
    }
  }

  void _manageDevices(Map<String, dynamic> client) {
    bool isMobile = MediaQuery.of(context).size.width < 900;

    // Passing password here too for consistency if needed in future
    if (isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditClientDialog(
            client: client,
            currentPassword: client['Password'],
            onSave: _loadClients,
            initialTabIndex: 1,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => EditClientDialog(
          client: client,
          currentPassword: client['Password'],
          onSave: _loadClients,
          initialTabIndex: 1,
        ),
      );
    }
  }

  void _resetPassword(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => ResetPasswordDialog(
        client: client,
        currentPassword: client['Password'],
        onSave: _loadClients,
      ),
    );
  }

  Future<void> _toggleClientStatus(Map<String, dynamic> client) async {
    final bool currentStatus = client['IsActive'] == 1;
    final bool newStatus = !currentStatus;

    try {
      await _apiService.setClientActiveStatus(
        recNo: client['RecNo'],
        isActive: newStatus,
      );
      _loadClients();
      _showSuccessSnackbar(
        newStatus
            ? 'Client enabled successfully'
            : 'Client disabled successfully',
      );
    } catch (e) {
      _showErrorSnackbar('Failed to update client status: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}