// [UPDATE] lib/screens/channelscreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lottie/lottie.dart';
import '../../AdminService/channel_api_service.dart';
import '../../AdminService/input_type_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/add_channel.dart';
import '../../widgets/color_utils.dart';
import '../../widgets/orbit_loader.dart';
import '../../widgets/successscreen.dart';

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> with TickerProviderStateMixin {
  final ChannelApiService _apiService = ChannelApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _filteredChannels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _searchController.addListener(_filterChannels);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- UPDATED: Added silent parameter to prevent Lottie loader on updates ---
  Future<void> _loadChannels({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final channels = await _apiService.getAllChannels();
      if (mounted) {
        setState(() {
          _channels = channels;
          _filteredChannels = channels;
          _isLoading = false;
        });
        // Re-apply filter if search text exists
        if (_searchController.text.isNotEmpty) {
          _filterChannels();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackbar('Failed to load channels: $e');
      }
    }
  }

  void _filterChannels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChannels = _channels.where((channel) {
        return channel['ChannelName'].toString().toLowerCase().contains(query) ||
            channel['Unit'].toString().toLowerCase().contains(query) ||
            (channel['ChannelID']?.toString().toLowerCase() ?? '').contains(query);
      }).toList();
    });
  }


  Future<void> _deleteChannel(int recNo) async {
    try {
      await _apiService.deleteChannel(recNo);
      _showSuccessSnackbar('Channel deleted successfully');
      _loadChannels(silent: true); // Refresh list silently
    } catch (e) {
      String errorMessage = e.toString();

      // Remove "Exception: " prefix if present
      if (errorMessage.startsWith("Exception: ")) {
        errorMessage = errorMessage.substring(11);
      }

      showErrorSnackbar(
        errorMessage,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void showErrorSnackbar(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
      ),
    );
  }

  void _addChannel() {
    // 1. Gather all colors currently used by existing channels
    final List<String> usedColors = _channels
        .map((c) => c['GraphLineColour']?.toString().toUpperCase() ?? '')
        .toList();

    // 2. Get the next best unique color from our 64-color palette
    final Color suggestedColor = ColorUtils.getNextUniqueColor(usedColors);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AddChannelDialog(
          // Pass the unique color to the Add dialog
          initialColor: suggestedColor,
          onSave: (String newChannelName) {
            Navigator.pop(context);
            _loadChannels();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SuccessScreen(
                message: "Channel '$newChannelName' Added Successfully!",
              ),
            ));
          },
        );
      },
    );
  }

  // --- UPDATED: Removes SuccessScreen (Lottie) and uses Snackbar + Silent Reload ---
  void _editChannel(Map<String, dynamic> channel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Channel',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: EditChannelForm(
              channel: channel,
              onSave: (String updatedChannelName) {
                Navigator.pop(context);

                // 1. Silent reload (No full screen Lottie loader)
                _loadChannels(silent: true);

                // 2. Snackbar (No SuccessScreen Lottie)
                _showSuccessSnackbar("Channel '$updatedChannelName' Updated Successfully!");
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Column(
      children: [
        _buildHeaderBar(isDesktop)
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: -0.2, curve: Curves.easeOut),
        SizedBox(height: isDesktop ? 32 : 20),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _filteredChannels.isEmpty
              ? _buildEmptyState(isDesktop)
              : isDesktop
              ? _buildDesktopTable()
              : _buildMobileCards(),
        ),
      ],
    );
  }

  // ... (Rest of the file remains exactly the same: _buildHeaderBar, _buildLoadingState, etc.)
  // Included strictly necessary parts for context, the rest is standard UI code

  Widget _buildHeaderBar(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 18 : 14,
            ),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderGrey.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Iconsax.search_normal_1, color: AppTheme.bodyText, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by Name, Unit, or ID...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.bodyText.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () => _searchController.clear(),
                    icon: Icon(Iconsax.close_circle, color: AppTheme.bodyText, size: 20),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: isDesktop ? 56 : 50,
          width: isDesktop ? 56 : 50,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
            border: Border.all(color: AppTheme.borderGrey.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => _loadChannels(),
            icon: _isLoading
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
            )
                : Icon(Iconsax.refresh, color: AppTheme.bodyText, size: 20),
            tooltip: 'Reload List',
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _addChannel,
            icon: const Icon(Iconsax.add, size: 18),
            label: Text(
              'New Channel',
              style:  GoogleFonts.bebasNeue(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.defaultBorderRadius,
              ),
              elevation: 2,
              shadowColor: AppTheme.shadowColor,
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const OrbitLoader(size: 120),
          const SizedBox(height: 32),
          Text(
            'Loading channels...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.bodyText,
              letterSpacing: 1.2,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(begin: 0.5),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDesktop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.radar_2, size: isDesktop ? 64 : 48, color: AppTheme.primaryBlue.withOpacity(0.5))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty ? 'No channels found' : 'No results for "${_searchController.text}"',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.darkText),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.shadowColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('ID', flex: 1),
                _buildHeaderCell('Channel Name', flex: 4),
                _buildHeaderCell('Input Type', flex: 2),
                _buildHeaderCell('Alarm', flex: 1),
                _buildHeaderCell('Chart', flex: 1),
                _buildHeaderCell('Actions', flex: 2),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _filteredChannels.length,
              separatorBuilder: (ctx, i) => Divider(height: 1, color: AppTheme.borderGrey.withOpacity(0.5)),
              itemBuilder: (ctx, i) => _buildDesktopRow(_filteredChannels[i], i),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.darkText),
      ),
    );
  }

  String _getInputTypeName(int id) {
    switch (id) {
      case 0: return 'Skip';
      case 1: return 'J-T/C (Non-Linear)';
      case 2: return 'K-T/C (Non-Linear)';
      case 3: return 'R-T/C (Non-Linear)';
      case 4: return 'PT100 (Non-Linear)';
      case 5: return '4-20mA (Linear)';
      default: return 'Unknown ($id)';
    }
  }

  Widget _buildDesktopRow(Map<String, dynamic> channel, int index) {
    final theme = Theme.of(context);
    final alarmColor = _parseColor(channel['TargetAlarmColour']);
    final chartColor = _parseColor(channel['GraphLineColour']);

    return InkWell(
      onTap: () => _showChannelDetailsDialog(channel),
      hoverColor: AppTheme.primaryBlue.withOpacity(0.03),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                channel['ChannelID'] ?? '-',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                channel['ChannelName'] ?? 'N/A',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.darkText),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
                flex: 2,
                child: Text(
                    _getInputTypeName(channel['ChannelInputType'] ?? 0),
                    style: theme.textTheme.bodyMedium
                )
            ),
            Expanded(
                flex: 1,
                child: _buildColorIndicator(
                    alarmColor,
                    channel['TargetAlarmColour'] ?? 'N/A'
                )
            ),
            Expanded(
                flex: 1,
                child: _buildColorIndicator(
                    chartColor,
                    channel['GraphLineColour'] ?? 'N/A'
                )
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _buildActionButton(Iconsax.eye, AppTheme.primaryBlue, 'Details', () => _showChannelDetailsDialog(channel)),
                  const SizedBox(width: 8),
                  _buildActionButton(Iconsax.edit, AppTheme.accentPurple, 'Edit', () => _editChannel(channel)),
                  const SizedBox(width: 8),
                  _buildActionButton(Iconsax.trash, AppTheme.accentRed, 'Delete', () => _confirmDelete(channel)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms);
  }

  Widget _buildColorIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderGrey)
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCards() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80, left: 4, right: 4),
      itemCount: _filteredChannels.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildMobileCard(_filteredChannels[index], index),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> channel, int index) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: AppTheme.shadowColor.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                          channel['ChannelName'] ?? 'N/A',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                      ),
                      child: Text(
                        channel['ChannelID'] ?? '-',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Iconsax.activity, size: 14, color: AppTheme.bodyText),
                    const SizedBox(width: 8),
                    Text('Input Type:', style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.bodyText)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_getInputTypeName(channel['ChannelInputType'] ?? 0), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: AppTheme.darkText))),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderGrey.withOpacity(0.5)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMobileActionButton(context, icon: Iconsax.eye, text: 'Details', color: AppTheme.primaryBlue, onTap: () => _showChannelDetailsDialog(channel)),
                _buildMobileActionButton(context, icon: Iconsax.edit, text: 'Edit', color: AppTheme.accentPurple, onTap: () => _editChannel(channel)),
                _buildMobileActionButton(context, icon: Iconsax.trash, text: 'Delete', color: AppTheme.accentRed, onTap: () => _confirmDelete(channel)),
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildMobileActionButton(BuildContext context, {required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: color.withOpacity(0.1),
            splashColor: color.withOpacity(0.2),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: color.withOpacity(0.15),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  void _showChannelDetailsDialog(Map<String, dynamic> channel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: _buildDetailsDialogContent(channel),
          ),
        );
      },
    );
  }


  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }


  Widget _buildDetailsDialogContent(Map<String, dynamic> channel) {

    final theme = Theme.of(context);
    final themeColor = _parseColor(channel['GraphLineColour']);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final isLinear = channel['ChannelInputType'] == 5;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: isDesktop ? 500 : size.width * 0.9,
        height: size.height,
        margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(left: 40),
        decoration: BoxDecoration(
          color: AppTheme.background,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.radar_2, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              channel['ChannelID'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            channel['ChannelName'] ?? 'Unknown Channel',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Iconsax.close_circle, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionHeader('General Information', Iconsax.info_circle, AppTheme.primaryBlue),
                  const SizedBox(height: 16),
                  _buildInfoGrid([
                    _buildInfoTile('Channel ID', channel['ChannelID'], Iconsax.tag, centered: false),
                    _buildInfoTile('Input Type', _getInputTypeName(channel['ChannelInputType'] ?? 0), Iconsax.activity),
                    _buildInfoTile('Unit', channel['Unit'], Iconsax.ruler),
                    _buildInfoTile('Rec No', '#${channel['RecNo']}', Iconsax.hashtag),
                    _buildInfoTile('Resolution', '${channel['Resolution']}', Iconsax.decred_dcr),
                    _buildInfoTile('Offset Value', '${channel['Offset']}', Iconsax.add_square),
                  ]),

                  const SizedBox(height: 32),

                  if (isLinear)
                    ...[
                      _buildSectionHeader('Linear Input Calibration', Iconsax.setting_4, AppTheme.accentGreen),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.accentGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildInfoTile('Low Value', '${channel['LowValue']}', Iconsax.arrow_down_1, centered: true)),
                            Container(width: 1, height: 40, color: AppTheme.borderGrey),
                            Expanded(child: _buildInfoTile('High Value', '${channel['HighValue']}', Iconsax.arrow_up_3, centered: true)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                  _buildSectionHeader('Alarm Configuration', Iconsax.notification, AppTheme.accentRed),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildInfoTile('Low Limit', '${channel['LowLimits']}', Iconsax.arrow_down_1, centered: true)),
                            Container(width: 1, height: 40, color: AppTheme.borderGrey),
                            Expanded(child: _buildInfoTile('High Limit', '${channel['HighLimits']}', Iconsax.arrow_up_3, centered: true)),
                          ],
                        ),
                        const Divider(height: 32),
                        _buildColorRow('Alarm Color', channel['TargetAlarmColour']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('Chart Configuration', Iconsax.graph, AppTheme.accentGreen),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.2)),
                    ),
                    child: _buildColorRow('Graph Color', channel['GraphLineColour']),
                  ),


                  const SizedBox(height: 32),
                  _buildSectionHeader('Metadata', Iconsax.document_code, AppTheme.accentPurple),
                  const SizedBox(height: 16),
                  _buildInfoTile('Created At', _formatDate(channel['CreatedAt']), Iconsax.calendar_1, fullWidth: true),
                  const SizedBox(height: 48),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(top: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(channel);
                      },
                      icon: Icon(Iconsax.trash, size: 18, color: AppTheme.accentRed),
                      label: Text(
                        'Delete',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.accentRed.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editChannel(channel);
                      },
                      icon: const Icon(Iconsax.edit_2, size: 18),
                      label: const Text('Edit Channel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ... (Helpers: _buildSectionHeader, _buildInfoGrid, etc. unchanged)
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
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

  Widget _buildInfoGrid(List<Widget> children) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: children,
    );
  }

  Widget _buildInfoTile(String label, dynamic value, IconData icon, {bool fullWidth = false, bool centered = false}) {
    final theme = Theme.of(context);
    return Container(
      width: fullWidth ? double.infinity : (centered ? null : 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.bodyText.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.bodyText.withOpacity(0.8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value?.toString() ?? 'N/A',
            style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.darkText, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, String? colorHex) {
    final theme = Theme.of(context);
    final color = _parseColor(colorHex);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Text(
                colorHex ?? '#------',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.bodyText)
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
              ),
            ),
          ],
        )
      ],
    );
  }

  void _confirmDelete(Map<String, dynamic> channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('CONFIRM DELETE', style: Theme.of(context).textTheme.titleLarge),
        content: Text('Are you sure you want to delete "${channel['ChannelName']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.bodyText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteChannel(channel['RecNo']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return AppTheme.primaryBlue;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.primaryBlue;
    }
  }
}

class EditChannelForm extends StatefulWidget {
  final Map<String, dynamic> channel;
  final Function(String channelName) onSave;

  const EditChannelForm({super.key, required this.channel, required this.onSave});

  @override
  State<EditChannelForm> createState() => _EditChannelFormState();
}

class _EditChannelFormState extends State<EditChannelForm> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ChannelApiService();
  final _inputTypeApiService = InputTypeApiService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _inputTypeOptions = [];

  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _resolutionController;
  late TextEditingController _lowLimitsController;
  late TextEditingController _highLimitsController;
  late TextEditingController _lowValueController;
  late TextEditingController _highValueController;
  late TextEditingController _offsetController;

  late Color _alarmColor;
  late Color _lineColor;

  int? _selectedInputTypeID;
  bool get _isLinear => _selectedInputTypeID == 5;

  Color _parseColor(String? colorString, Color defaultColor) {
    if (colorString == null || colorString.isEmpty) return defaultColor;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return defaultColor;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _loadInputTypes();
    final c = widget.channel;

    _nameController = TextEditingController(text: c['ChannelName'] ?? '');
    _unitController = TextEditingController(text: c['Unit'] ?? '');
    _resolutionController = TextEditingController(text: c['Resolution']?.toString() ?? '2');
    _lowLimitsController = TextEditingController(text: c['LowLimits']?.toString() ?? '0.0');
    _highLimitsController = TextEditingController(text: c['HighLimits']?.toString() ?? '100.0');

    _lowValueController = TextEditingController(text: c['LowValue']?.toString() ?? '-9999.0');
    _highValueController = TextEditingController(text: c['HighValue']?.toString() ?? '9999.0');
    _offsetController = TextEditingController(text: c['Offset']?.toString() ?? '0.0');

    _alarmColor = _parseColor(c['TargetAlarmColour'], AppTheme.accentRed);
    _lineColor = _parseColor(c['GraphLineColour'], AppTheme.primaryBlue);

    _selectedInputTypeID = c['ChannelInputType'] as int?;
  }

  Future<void> _loadInputTypes() async {
    try {
      final types = await _inputTypeApiService.getAllInputTypes();
      setState(() {
        _inputTypeOptions = types;
        if (_selectedInputTypeID == null && types.isNotEmpty) {
          _selectedInputTypeID = types.firstWhere(
                  (type) => type['InputTypeID'] != 0,
              orElse: () => types.first
          )['InputTypeID'] as int?;
        }
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _resolutionController.dispose();
    _lowLimitsController.dispose();
    _highLimitsController.dispose();
    _lowValueController.dispose();
    _highValueController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  Future<void> _saveChannel() async {
    if (!_formKey.currentState!.validate() || _selectedInputTypeID == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select an Input Type and fix the errors.'),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Pass original values for removed fields to API
      await _apiService.updateChannel(
        recNo: widget.channel['RecNo'],
        channelName: _nameController.text,
        startingCharacter: widget.channel['StartingCharacter'], // Use original
        dataLength: widget.channel['DataLength'], // Use original

        channelInputType: _selectedInputTypeID,
        resolution: int.tryParse(_resolutionController.text),
        unit: _unitController.text,
        lowLimits: double.tryParse(_lowLimitsController.text),
        highLimits: double.tryParse(_highLimitsController.text),
        offset: double.tryParse(_offsetController.text),
        targetAlarmColour: _colorToHex(_alarmColor),
        graphLineColour: _colorToHex(_lineColor),
        lowValue: _isLinear ? double.tryParse(_lowValueController.text) : null,
        highValue: _isLinear ? double.tryParse(_highValueController.text) : null,
      );

      widget.onSave(_nameController.text);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update channel: $e'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Build method for EditChannelForm ... (matches previous, just ensuring class completeness)
  @override
  Widget build(BuildContext context) {
    // ... (Same as provided code) ...
    // Content omitted to save space, but logically the _EditChannelFormState build method remains exactly as you provided it.
    // I am returning the full previous structure for the EditForm below to be safe.

    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final c = widget.channel;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: isDesktop ? 500 : size.width * 0.9,
          height: size.height,
          margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(left: 40),
          decoration: BoxDecoration(
            color: AppTheme.background,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentPurple, AppTheme.accentPurple.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.edit_2, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                c['ChannelID'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'EDIT CHANNEL',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c['ChannelName'] ?? 'Unknown Channel',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Iconsax.close_circle, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildSectionHeader('General Information', Iconsax.info_circle, AppTheme.primaryBlue),
                      const SizedBox(height: 16),
                      _buildInfoTile('Channel ID', c['ChannelID'], Iconsax.tag, readOnly: true),
                      const SizedBox(height: 16),

                      _buildInputTypeDropdown(),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _nameController,
                        label: 'Channel Name',
                        icon: Iconsax.radar_2,
                        validator: null, // REMOVED VALIDATOR
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: _unitController,
                              label: 'Unit *',
                              icon: Iconsax.ruler,
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFormField(
                              controller: _resolutionController,
                              label: 'Resolution (Decimals) *',
                              icon: Iconsax.decred_dcr,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Removed Row with Start Char and Data Length Fields
                      _buildTextFormField(
                        controller: _offsetController,
                        label: 'Offset (-9999 to +9999) *',
                        icon: Iconsax.add_square,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final val = double.tryParse(v);
                          if (val == null) return 'Invalid number';
                          if (val < -9999 || val > 9999) return 'Must be between -9999 and +9999';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile('Record Number', '#${c['RecNo']}', Iconsax.hashtag, readOnly: true),

                      const SizedBox(height: 32),

                      if (_isLinear)
                        ...[
                          _buildSectionHeader('Linear Input Calibration', Iconsax.setting_4, AppTheme.accentGreen),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextFormField(
                                  controller: _lowValueController,
                                  label: 'Low Value *',
                                  icon: Iconsax.arrow_down_1,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextFormField(
                                  controller: _highValueController,
                                  label: 'High Value *',
                                  icon: Iconsax.arrow_up_3,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],

                      _buildSectionHeader('Alarm Configuration', Iconsax.notification, AppTheme.accentRed),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: _lowLimitsController,
                              label: 'Low Limit *',
                              icon: Iconsax.arrow_down_1,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFormField(
                              controller: _highLimitsController,
                              label: 'High Limit *',
                              icon: Iconsax.arrow_up_3,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildColorPickerInput(
                          label: 'Alarm Color',
                          icon: Iconsax.color_swatch,
                          color: _alarmColor,
                          onColorChanged: (newColor) {
                            setState(() => _alarmColor = newColor);
                          }
                      ),
                      const SizedBox(height: 32),

                      _buildSectionHeader('Chart Configuration', Iconsax.graph, AppTheme.accentGreen),
                      const SizedBox(height: 16),
                      _buildColorPickerInput(
                          label: 'Graph Line Color',
                          icon: Iconsax.colors_square,
                          color: _lineColor,
                          onColorChanged: (newColor) {
                            setState(() => _lineColor = newColor);
                          }
                      ),

                      const SizedBox(height: 32),

                      _buildSectionHeader('Metadata', Iconsax.document_code, AppTheme.accentPurple),
                      const SizedBox(height: 16),
                      _buildInfoTile('Created At', formatDate(c['CreatedAt']), Iconsax.calendar_1, readOnly: true),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border(top: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.borderGrey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: AppTheme.bodyText, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveChannel,
                        icon: _isLoading
                            ? Container(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Iconsax.save_2, size: 18),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper widgets for EditChannelForm also included...
  // (Included to maintain file integrity)
  Widget _buildInputTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedInputTypeID,
        decoration: InputDecoration(
          labelText: 'Input Type *',
          labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
          prefixIcon: Icon(Iconsax.activity, color: AppTheme.primaryBlue, size: 20),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 16, bottom: 16),
        ),
        hint: const Text('Select Input Type'),
        items: _inputTypeOptions.map((type) {
          final isLinear = type['InputTypeID'] == 5;
          final typeName = type['TypeName'] as String;
          final designation = isLinear ? ' (Linear)' : ' (Non-Linear)';

          return DropdownMenuItem<int>(
            value: type['InputTypeID'] as int,
            child: Text(
                typeName + designation,
                style: const TextStyle(color: AppTheme.darkText)
            ),
          );
        }).toList(),
        onChanged: (int? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedInputTypeID = newValue;
            });
          }
        },
        validator: (v) => v == null ? 'Input Type is required' : null,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    List<TextInputFormatter>? formatters = inputFormatters;
    if (keyboardType != null && keyboardType == const TextInputType.numberWithOptions(decimal: true, signed: true) && inputFormatters == null) {
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))];
    } else if (keyboardType != null && keyboardType == const TextInputType.numberWithOptions(decimal: true) && inputFormatters == null) {
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    }

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.bodyText.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        filled: true,
        fillColor: AppTheme.lightGrey.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderGrey.withOpacity(0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentRed, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentRed, width: 2)),
      ),
    );
  }

  Widget _buildInfoTile(String label, dynamic value, IconData icon, {bool readOnly = true}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(readOnly ? 0.3 : 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey.withOpacity(readOnly ? 0.2 : 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.bodyText.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.bodyText.withOpacity(0.8), fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value?.toString() ?? 'N/A', style: theme.textTheme.titleMedium?.copyWith(color: readOnly ? AppTheme.bodyText : AppTheme.darkText, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2), thickness: 1)),
      ],
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildColorPickerInput({required String label, required IconData icon, required Color color, required ValueChanged<Color> onColorChanged}) {
    return InkWell(
      onTap: () => _showColorPickerDialog(label, color, onColorChanged),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(color: AppTheme.lightGrey.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5))),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: AppTheme.bodyText.withOpacity(0.8), fontSize: 16)),
            const Spacer(),
            Container(width: 28, height: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderGrey))),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = currentColor;
        return AlertDialog(
          title: Text('Pick $title'),
          content: SingleChildScrollView(child: MaterialPicker(pickerColor: currentColor, onColorChanged: (color) => tempColor = color, enableLabel: true)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () { onColorChanged(tempColor); Navigator.pop(context); }, child: const Text('Select')),
          ],
        );
      },
    );
  }
}