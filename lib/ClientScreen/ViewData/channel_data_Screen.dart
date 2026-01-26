import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../ClinetService/data_api_service.dart';
import '../../provider/client_provider.dart';
import '../../theme/client_theme.dart';
import '../../widgets/constants.dart';
import '../../widgets/timezone_helper.dart';
import 'channel_data_model.dart';
import 'data_export_screen.dart';

enum DataViewMode { graph, table, both }

class ChannelDataScreen extends StatefulWidget {
  final List<dynamic> selectedChannels;

  const ChannelDataScreen({super.key, required this.selectedChannels});

  @override
  State<ChannelDataScreen> createState() => _ChannelDataScreenState();
}

class _ChannelDataScreenState extends State<ChannelDataScreen> {
  final DataApiService _dataService = DataApiService();
  final ScreenshotController _screenshotController = ScreenshotController();

  List<ChannelDataPoint> _dataPoints = [];
  Map<String, double> _peakValues = {};

  bool _isLoading = false;
  Timer? _pollingTimer;
  final int _pollingSeconds = 30;
  bool _isLiveActive = true;
  bool _isHistoricalMode = false;

  late List<Map<String, dynamic>> _customizableChannels;
  Set<String> _visiblePeakChannelIds = {};

  DataViewMode _currentView = DataViewMode.both;
  double _splitRatio = 0.6;

  DateTime _startDate = DateTime.now().subtract(const Duration(minutes: 60));
  DateTime _endDate = DateTime.now();
  DateTime? _lastApiCallTime;

  String _selectedTimeFilter = "Live (1h)";

  final List<String> _timeFilterOptions = [
    "Live (1h)",
    "Live (4h)",
    "Live (24h)",
    "Live (7d)",
    "Live (30d)",
  ];

  @override
  void initState() {
    super.initState();
    _customizableChannels = widget.selectedChannels.map((channel) {
      return Map<String, dynamic>.from(channel)..['isVisible'] = true;
    }).toList();

    _visiblePeakChannelIds = _customizableChannels
        .map((c) => c['ChannelRecNo'].toString())
        .toSet();

    _resetToStandardLive();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    if (_isLiveActive && !_isHistoricalMode) {
      _pollingTimer = Timer.periodic(Duration(seconds: _pollingSeconds), (timer) {
        if (mounted) {
          final now = DateTime.now();
          if (_lastApiCallTime != null) {
            _startDate = _lastApiCallTime!;
          } else {
            _startDate = now.subtract(const Duration(seconds: 30));
          }
          _endDate = now;
          _fetchData(isBackground: true, isAppend: true);
        }
      });
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _toggleLiveStatus() {
    if (_isHistoricalMode) return;

    setState(() {
      _isLiveActive = !_isLiveActive;
    });
    if (_isLiveActive) {
      _lastApiCallTime = DateTime.now().subtract(const Duration(seconds: 30));
      _startDate = _lastApiCallTime!;
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  Future<void> _fetchData({bool isBackground = false, bool isAppend = false}) async {
    if (!mounted) return;
    if (!isBackground && !isAppend) setState(() => _isLoading = true);

    final provider = Provider.of<ClientProvider>(context, listen: false);
    final activeChannels = _customizableChannels.where((c) => c['isVisible'] ?? true).toList();

    if (provider.selectedDeviceRecNo == null || activeChannels.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final channelRecNos = activeChannels.map((c) => c['ChannelRecNo'].toString()).join(',');
    final apiFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    try {
      final rawData = await _dataService.fetchChannelData(
        deviceRecNo: provider.selectedDeviceRecNo!,
        startDate: apiFormat.format(_startDate),
        endDate: apiFormat.format(_endDate),
        channelRecNos: channelRecNos,
      );

      Map<String, Map<String, dynamic>> groupedData = {};
      for (var item in rawData) {
        String timeKey = item['AbsDateTime'].toString();
        if (timeKey.length > 19) timeKey = timeKey.substring(0, 19);

        if (!groupedData.containsKey(timeKey)) {
          groupedData[timeKey] = {};
        }

        String chNo = item['ChannelRecNo'].toString();
        dynamic val = item['Value'];
        groupedData[timeKey]![chNo] = val;
      }

      String deviceLocation = provider.selectedDeviceLocation;
      final List<ChannelDataPoint> newPoints = [];

      groupedData.forEach((timeStr, valuesMap) {
        DateTime? istTime = DateTime.tryParse(timeStr);
        if (istTime != null) {
          DateTime displayTime = TimeZoneHelper.convertIstToCountryTime(istTime, deviceLocation);
          Map<String, dynamic> cleanValues = valuesMap.map((k, v) {
            double? parsedVal = double.tryParse(v.toString());
            return MapEntry(k, parsedVal);
          });
          newPoints.add(ChannelDataPoint(displayTime, cleanValues));
        }
      });

      if (mounted) {
        setState(() {
          if (isAppend) {
            _dataPoints.addAll(newPoints);
          } else {
            _dataPoints = newPoints;
          }

          _dataPoints.sort((a, b) => a.dateTime.compareTo(b.dateTime));

          if (_dataPoints.isNotEmpty) {
            final oldestPoint = _dataPoints.first;
            for (var c in activeChannels) {
              String id = c['ChannelRecNo'].toString();
              if (oldestPoint.values[id] == null) {
                oldestPoint.values[id] = 0.0;
              }
            }
          }

          Map<String, double> peaks = {};
          for (var c in activeChannels) {
            String id = c['ChannelRecNo'].toString();
            double max = -double.infinity;
            for (var p in _dataPoints) {
              double? v = p.values[id] as double?;
              if (v != null && v > max) max = v;
            }
            peaks[id] = max == -double.infinity ? 0.0 : max;
          }
          _peakValues = peaks;
          _lastApiCallTime = _endDate;
        });

        if (newPoints.isNotEmpty && _isLiveActive) {
          _checkNewPointsForAlarms(newPoints, activeChannels, provider.selectedDeviceRecNo!);
        }
      }
    } catch (e) {
      debugPrint("Error fetching/parsing data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkNewPointsForAlarms(List<ChannelDataPoint> newPoints, List<Map<String, dynamic>> channels, int deviceRecNo) {
    debugPrint("[ALARM] Checking ${newPoints.length} new data points for alarms...");
    for (var point in newPoints) {
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        String name = c['ChannelName'] ?? 'Unknown';

        double? val = point.values[id] as double?;
        double? highLimit = double.tryParse(c['Effective_HighLimits']?.toString() ?? '');
        double? lowLimit = double.tryParse(c['Effective_LowLimits']?.toString() ?? '');

        if (val == null) continue;

        bool isHigh = (highLimit != null && val > highLimit);
        bool isLow = (lowLimit != null && val < lowLimit);

        if (isHigh || isLow) {
          debugPrint("[ALARM TRIGGER] $name Value: $val (High: $highLimit, Low: $lowLimit)");
          _triggerAlarmBackend(
            deviceRecNo: deviceRecNo,
            channelRecNo: int.parse(id),
            channelName: name,
            value: val,
            highLimit: highLimit,
            lowLimit: lowLimit,
          );
        }
      }
    }
  }

  Future<void> _triggerAlarmBackend({
    required int deviceRecNo,
    required int channelRecNo,
    required String channelName,
    required double value,
    double? highLimit,
    double? lowLimit
  }) async {
    final String baseUrl = '${ApiConstants.baseUrl}/process_alarms.php';

    try {
      final body = {
        "DeviceRecNo": deviceRecNo,
        "ChannelRecNo": channelRecNo,
        "ChannelName": channelName,
        "Value": value,
        "HighLimit": highLimit,
        "LowLimit": lowLimit
      };

      debugPrint("[ALARM SENDING] Sending alarm to backend...");
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      debugPrint("[ALARM RESPONSE] Code: ${response.statusCode} | Body: ${response.body}");
    } catch (e) {
      debugPrint("[ALARM FAILURE] Could not send alarm: $e");
    }
  }

  Future<void> _handleFilterPresetChange(String? newValue) async {
    if (newValue == null) return;
    setState(() {
      _selectedTimeFilter = newValue;
      _isHistoricalMode = false;
      _isLiveActive = true;
      _endDate = DateTime.now();
      _dataPoints.clear();
      _lastApiCallTime = null;

      switch (newValue) {
        case "Live (4h)":
          _startDate = _endDate.subtract(const Duration(hours: 4));
          break;
        case "Live (24h)":
          _startDate = _endDate.subtract(const Duration(hours: 24));
          break;
        case "Live (7d)":
          _startDate = _endDate.subtract(const Duration(days: 7));
          break;
        case "Live (30d)":
          _startDate = _endDate.subtract(const Duration(days: 30));
          break;
        case "Live (1h)":
        default:
          _startDate = _endDate.subtract(const Duration(hours: 1));
          break;
      }
    });

    _fetchData();
    _startPolling();
  }

  void _resetToStandardLive() {
    _handleFilterPresetChange("Live (1h)");
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: ClientTheme.primaryColor)),
          child: child!),
    );
    if (date == null) return null;

    if (!mounted) return null;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: ClientTheme.primaryColor)),
          child: child!),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _openCustomRangeDialog() async {
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Select Custom Range"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select start and end time for historical analysis.",
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              _buildDateTimeTile("Start Time", tempStart, () async {
                final picked = await _pickDateTime(tempStart);
                if (picked != null) setDialogState(() => tempStart = picked);
              }),
              const SizedBox(height: 12),
              _buildDateTimeTile("End Time", tempEnd, () async {
                final picked = await _pickDateTime(tempEnd);
                if (picked != null) setDialogState(() => tempEnd = picked);
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ClientTheme.primaryColor),
              onPressed: () {
                if (tempEnd.isBefore(tempStart)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End time must be after Start time")));
                  return;
                }
                Navigator.pop(context);

                setState(() {
                  _isHistoricalMode = true;
                  _isLiveActive = false;
                  _selectedTimeFilter = "Custom";
                  _startDate = tempStart;
                  _endDate = tempEnd;
                  _dataPoints.clear();
                  _lastApiCallTime = null;
                });
                _stopPolling();
                _fetchData();
              },
              child: const Text("APPLY FILTER", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  Widget _buildDateTimeTile(String label, DateTime dt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(DateFormat('MMM dd, yyyy  hh:mm a').format(dt),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientTheme.textDark)),
              ],
            ),
            const Icon(Iconsax.calendar_edit, size: 20, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    if (isMobile && _currentView == DataViewMode.both) _currentView = DataViewMode.graph;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, isMobile),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMergedControlsRow(isMobile),
              const SizedBox(height: 12),
              _buildPeakSummaryRow(),
              const SizedBox(height: 12),
              if (isMobile) ...[
                _buildMobileViewToggle(),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _isLoading && !isMobile
                    ? Center(child: CircularProgressIndicator(color: ClientTheme.primaryColor))
                    : (isMobile ? _buildMobileContent() : _buildDesktopContent()),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isMobile) {
    final provider = Provider.of<ClientProvider>(context);
    final String location = provider.selectedDeviceLocation;

    return AppBar(
      titleSpacing: 20,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _isHistoricalMode
                    ? Colors.purple.withOpacity(0.1)
                    : (_isLiveActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: _isHistoricalMode
                        ? Colors.purple.withOpacity(0.3)
                        : (_isLiveActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3)))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isHistoricalMode ? Colors.purple : (_isLiveActive ? Colors.green : Colors.grey)),
                ),
                const SizedBox(width: 8),
                Text(
                  _isHistoricalMode ? "HISTORICAL" : (_isLiveActive ? "LIVE FEED" : "PAUSED"),
                  style: TextStyle(
                      color: _isHistoricalMode ? Colors.purple : (_isLiveActive ? Colors.green[800] : Colors.grey[800]),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (!isMobile) Container(height: 24, width: 1, color: Colors.grey.shade300),
          if (!isMobile) const SizedBox(width: 16),
          if (!isMobile) ...[
            const Text("Monitor", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.1))),
              child: Row(
                children: [
                  const Icon(Iconsax.location, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(location, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: OutlinedButton.icon(
            icon: const Icon(Iconsax.export_1, size: 16),
            label: Text(isMobile ? "Exp" : "Export", style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: ClientTheme.textDark,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () async {
              Uint8List? graphBytes;
              try {
                graphBytes = await _screenshotController.capture(pixelRatio: 2.0);
              } catch (e) {
                debugPrint("Error capturing screenshot: $e");
              }

              DateTime exportStart = _startDate;
              DateTime exportEnd = _endDate;

              if (!_isHistoricalMode) {
                exportEnd = DateTime.now();
                switch (_selectedTimeFilter) {
                  case "Live (4h)":
                    exportStart = exportEnd.subtract(const Duration(hours: 4));
                    break;
                  case "Live (24h)":
                    exportStart = exportEnd.subtract(const Duration(hours: 24));
                    break;
                  case "Live (7d)":
                    exportStart = exportEnd.subtract(const Duration(days: 7));
                    break;
                  case "Live (30d)":
                    exportStart = exportEnd.subtract(const Duration(days: 30));
                    break;
                  case "Live (1h)":
                  default:
                    exportStart = exportEnd.subtract(const Duration(hours: 1));
                    break;
                }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => DataExportScreen(
                    deviceRecNo: 0,
                    passedData: _dataPoints,
                    passedChannels: _customizableChannels,
                    startDate: exportStart,
                    endDate: exportEnd,
                    graphImage: graphBytes,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Iconsax.setting_4),
          onPressed: _showChannelCustomizationDialog,
          tooltip: "Configure Graph Channels",
          style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200))),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMergedControlsRow(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: isMobile
          ? Column(
        children: [
          _buildPlayPauseBtn(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTimeFilterDropdown()),
              const SizedBox(width: 8),
              _buildCustomDateButtonWithText(),
            ],
          )
        ],
      )
          : Row(
        children: [
          _buildPlayPauseBtn(),
          const SizedBox(width: 16),
          Container(width: 1, height: 28, color: Colors.grey.shade300),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTimeFilterDropdown()),
                const SizedBox(width: 12),
                _buildCustomDateButtonWithText(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseBtn() {
    bool isInteractive = !_isHistoricalMode;
    return InkWell(
      onTap: isInteractive ? _toggleLiveStatus : _resetToStandardLive,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isInteractive
              ? (_isLiveActive ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08))
              : ClientTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isHistoricalMode ? Iconsax.refresh_2 : (_isLiveActive ? Iconsax.pause : Iconsax.play),
                size: 20,
                color: isInteractive
                    ? (_isLiveActive ? Colors.green[700] : Colors.orange[800])
                    : ClientTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              _isHistoricalMode ? "Back to Live" : (_isLiveActive ? "Pause" : "Resume"),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isInteractive
                      ? (_isLiveActive ? Colors.green[800] : Colors.orange[900])
                      : ClientTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterDropdown() {
    String displayValue = _isHistoricalMode ? "Custom Range" : _selectedTimeFilter;
    if (!_timeFilterOptions.contains(displayValue) && !_isHistoricalMode) {
      displayValue = "Live (5m)";
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _isHistoricalMode ? null : displayValue,
          hint: _isHistoricalMode
              ? Text("Custom Range Active", style: TextStyle(color: ClientTheme.primaryColor, fontWeight: FontWeight.bold))
              : null,
          isExpanded: true,
          icon: const Icon(Iconsax.arrow_down_1, size: 16),
          style: TextStyle(color: ClientTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600),
          onChanged: _handleFilterPresetChange,
          items: _timeFilterOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomDateButtonWithText() {
    return InkWell(
      onTap: _openCustomRangeDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _isHistoricalMode ? ClientTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isHistoricalMode ? ClientTheme.primaryColor : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.calendar_1,
              color: _isHistoricalMode ? Colors.white : Colors.black87,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              "Custom Range",
              style: TextStyle(
                  color: _isHistoricalMode ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakSummaryRow() {
    final visiblePeaks = _customizableChannels
        .where((c) => _visiblePeakChannelIds.contains(c['ChannelRecNo'].toString()))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          InkWell(
            onTap: _showPeakSelectionDialog,
            child: const Row(
              children: [
                Icon(Iconsax.star_1, size: 18, color: Colors.amber),
                SizedBox(width: 4),
                Text("PEAKS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Icon(Iconsax.arrow_down_1, size: 12, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: visiblePeaks.map((c) {
                      String id = c['ChannelRecNo'].toString();
                      Color col = Colors.grey;
                      try {
                        col = Color(int.parse(
                            'FF${c['Effective_GraphColor'].toString().replaceAll('#', '')}',
                            radix: 16));
                      } catch (e) {
                        col = ClientTheme.primaryColor;
                      }

                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: col.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: col.withOpacity(0.3))),
                        child: Text(
                            "${c['ChannelName']}: ${_peakValues[id]?.toStringAsFixed(2) ?? '0.00'}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  )))
        ],
      ),
    );
  }

  void _showPeakSelectionDialog() {
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Select Peak Channels"),
            content: SizedBox(
              width: 300,
              height: 400,
              child: ListView(
                children: _customizableChannels.map((c) {
                  String id = c['ChannelRecNo'].toString();
                  bool isSelected = _visiblePeakChannelIds.contains(id);
                  return CheckboxListTile(
                    title: Text(c['ChannelName']?.toString() ?? 'Unknown'),
                    value: isSelected,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          _visiblePeakChannelIds.add(id);
                        } else {
                          _visiblePeakChannelIds.remove(id);
                        }
                      });
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
          );
        }));
  }

  Widget _buildMobileViewToggle() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildMobileToggleBtn("Graph View", Iconsax.graph, DataViewMode.graph),
          _buildMobileToggleBtn("Table View", Iconsax.grid_1, DataViewMode.table),
        ],
      ),
    );
  }

  Widget _buildMobileToggleBtn(String label, IconData icon, DataViewMode mode) {
    final isSelected = _currentView == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentView = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? ClientTheme.primaryColor : Colors.grey),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? ClientTheme.textDark : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileContent() {
    if (_currentView == DataViewMode.table) return _buildTableContainer(isMobile: true);
    return _buildGraphContainer(isMobile: true);
  }

  Widget _buildDesktopContent() {
    if (_currentView == DataViewMode.graph) return _buildGraphContainer(isExpanded: true);
    if (_currentView == DataViewMode.table) return _buildTableContainer(isExpanded: true);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final graphW = (width * _splitRatio).clamp(width * 0.2, width * 0.8);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: graphW, child: _buildGraphContainer()),
            _buildResizer(width),
            Expanded(child: _buildTableContainer()),
          ],
        );
      },
    );
  }

  Widget _buildResizer(double totalWidth) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => setState(() {
          _splitRatio = (_splitRatio + d.delta.dx / totalWidth).clamp(0.2, 0.8);
        }),
        child: Container(
          width: 16,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        ),
      ),
    );
  }

  Widget _buildGraphContainer({bool isExpanded = false, bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Trend Analysis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (!isMobile)
                IconButton(
                  icon: Icon(isExpanded ? Iconsax.minus : Iconsax.maximize_3, size: 20),
                  tooltip: isExpanded ? "Restore Split View" : "Maximize Graph",
                  onPressed: () => setState(() => _currentView = isExpanded ? DataViewMode.both : DataViewMode.graph),
                )
            ],
          ),
          const Divider(),
          Expanded(
              child: _dataPoints.isEmpty
                  ? Center(child: Text("Waiting for data...", style: ClientTheme.themeData.textTheme.bodyMedium))
                  : _buildSyncfusionLineChart()),
        ],
      ),
    );
  }

  List<PlotBand> _buildTargetLines() {
    List<PlotBand> bands = [];
    final activeChannels = _customizableChannels.where((c) => c['isVisible'] ?? true).toList();

    for (var c in activeChannels) {
      double? highLimit = double.tryParse(c['Effective_HighLimits']?.toString() ?? '');
      double? lowLimit = double.tryParse(c['Effective_LowLimits']?.toString() ?? '');

      Color alarmColor = Colors.red;
      try {
        String? hex = c['Effective_AlarmColor']?.toString().replaceAll('#', '');
        if (hex != null && hex.isNotEmpty) alarmColor = Color(int.parse('FF$hex', radix: 16));
      } catch(e) {}

      if (highLimit != null) {
        bands.add(PlotBand(
          start: highLimit,
          end: highLimit,
          borderWidth: 1,
          borderColor: alarmColor.withOpacity(0.7),
          dashArray: const <double>[5, 5],
          text: 'High ${c['ChannelName'] ?? ''}',
          textStyle: TextStyle(color: alarmColor, fontSize: 10),
          horizontalTextAlignment: TextAnchor.end,
        ));
      }
      if (lowLimit != null) {
        bands.add(PlotBand(
          start: lowLimit,
          end: lowLimit,
          borderWidth: 1,
          borderColor: alarmColor.withOpacity(0.7),
          dashArray: const <double>[5, 5],
          text: 'Low ${c['ChannelName'] ?? ''}',
          textStyle: TextStyle(color: alarmColor, fontSize: 10),
          horizontalTextAlignment: TextAnchor.end,
        ));
      }
    }
    return bands;
  }

// --- CHART WIDGET ---
  Widget _buildSyncfusionLineChart() {
    final visibleChannels = _customizableChannels.where((c) => c['isVisible'] ?? true).toList();
    List<CartesianSeries> series = [];

    for (var c in visibleChannels) {
      String id = c['ChannelRecNo'].toString();

      // 1. Get Normal Graph Color
      Color graphColor = Colors.blue;
      try {
        String colorHex = c['Effective_GraphColor']?.toString().replaceAll('#', '') ?? '2563EB';
        graphColor = Color(int.parse('FF$colorHex', radix: 16));
      } catch (e) {
        graphColor = Colors.blue;
      }

      // 2. Get Limits
      double? highLimit = double.tryParse(c['Effective_HighLimits']?.toString() ?? '');
      double? lowLimit = double.tryParse(c['Effective_LowLimits']?.toString() ?? '');

      // 3. Get Alarm Color
      Color alarmColor = Colors.red;
      try {
        String? alarmHex = c['Effective_AlarmColor']?.toString().replaceAll('#', '');
        if (alarmHex != null && alarmHex.isNotEmpty) {
          alarmColor = Color(int.parse('FF$alarmHex', radix: 16));
        }
      } catch (e) {
        alarmColor = Colors.red;
      }

      series.add(LineSeries<ChannelDataPoint, DateTime>(
        dataSource: _dataPoints,
        xValueMapper: (d, _) => d.dateTime,
        yValueMapper: (d, _) => d.values[id] as double?,
        name: c['ChannelName']?.toString() ?? 'CH $id',
        color: graphColor,
        width: 2.0,
        animationDuration: 0,
        emptyPointSettings: const EmptyPointSettings(mode: EmptyPointMode.gap),

        // === HIGHLIGHT LOGIC ===
        // This makes the line turn Alarm Color ONLY when limits are crossed
        pointColorMapper: (ChannelDataPoint data, int index) {
          double? val = data.values[id] as double?;
          if (val == null) return graphColor;

          if (highLimit != null && val > highLimit) {
            return alarmColor; // Highlight High
          }
          if (lowLimit != null && val < lowLimit) {
            return alarmColor; // Highlight Low
          }
          return graphColor; // Normal
        },

        selectionBehavior: SelectionBehavior(
          enable: true,
          toggleSelection: true,
        ),
      ));
    }

    return Screenshot(
      controller: _screenshotController,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        backgroundColor: Colors.white,
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          toggleSeriesVisibility: true,
          overflowMode: LegendItemOverflowMode.wrap,
        ),
        primaryXAxis: DateTimeAxis(
            dateFormat: DateFormat('HH:mm:ss'),
            majorGridLines: const MajorGridLines(width: 0),
            edgeLabelPlacement: EdgeLabelPlacement.shift),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(width: 1, color: Colors.grey.withOpacity(0.1)),
          axisLine: const AxisLine(width: 0),
          rangePadding: ChartRangePadding.round,
          // REMOVED: plotBands (Dashed lines) as requested
        ),
        zoomPanBehavior: ZoomPanBehavior(
          enablePinching: true,
          enablePanning: true,
          zoomMode: ZoomMode.x,
        ),
        trackballBehavior: TrackballBehavior(
            enable: true,
            activationMode: ActivationMode.singleTap,
            tooltipSettings: const InteractiveTooltip(enable: true),
            tooltipDisplayMode: TrackballDisplayMode.groupAllPoints),
        series: series,
      ),
    );
  }

// [UPDATE] lib/ClientScreen/channel_data_Screen.dart

  Widget _buildTableContainer({bool isExpanded = false, bool isMobile = false}) {
    final visibleChannels = _customizableChannels.where((c) => c['isVisible'] ?? true).toList();

    const double colWidth = 120.0;
    const double timeColWidth = 90.0;
    const double dateColWidth = 100.0; // 🆕 Added Date Column Width

    // 🆕 Updated Total Width Calculation
    final double totalMinWidth = dateColWidth + timeColWidth + (visibleChannels.length * colWidth);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text("Data Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 12),
                    Text("${_dataPoints.length} Records",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                if (!isMobile)
                  IconButton(
                    icon: Icon(isExpanded ? Iconsax.minus : Iconsax.maximize_3, size: 20),
                    tooltip: isExpanded ? "Restore Split View" : "Maximize Table",
                    onPressed: () => setState(() => _currentView = isExpanded ? DataViewMode.both : DataViewMode.table),
                  )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final shouldScroll = totalMinWidth > constraints.maxWidth;
              final contentWidth = shouldScroll ? totalMinWidth : constraints.maxWidth;

              return ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.white, Colors.white, Colors.white.withOpacity(0.1)],
                    stops: const [0.0, 0.8, 0.9, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: Colors.grey[50],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          width: contentWidth,
                          child: Row(
                            children: [
                              // 🆕 Date Column Header
                              SizedBox(
                                  width: dateColWidth,
                                  child: Text('Date',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13, color: ClientTheme.textDark))),

                              SizedBox(
                                  width: timeColWidth,
                                  child: Text('Time',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13, color: ClientTheme.textDark))),
                              ...visibleChannels.map((c) => Expanded(
                                  child: Text(c['ChannelName']?.toString() ?? 'Unknown',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13, color: ClientTheme.textDark)))),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SizedBox(
                            width: contentWidth,
                            child: ListView.separated(
                              itemCount: _dataPoints.reversed.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final pt = _dataPoints[_dataPoints.length - 1 - idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // 🆕 Date Column Data (DD-MMM-YY)
                                      SizedBox(
                                          width: dateColWidth,
                                          child: Text(DateFormat('dd-MMM-yy').format(pt.dateTime),
                                              style: const TextStyle(fontSize: 13))),

                                      SizedBox(
                                          width: timeColWidth,
                                          child: Text(DateFormat('HH:mm:ss').format(pt.dateTime),
                                              style: const TextStyle(fontSize: 13))),
                                      ...visibleChannels.map((c) {
                                        String id = c['ChannelRecNo'].toString();
                                        double val = (pt.values[id] as num?)?.toDouble() ?? 0.0;
                                        double max = _peakValues[id] ?? 0.0;
                                        bool isPeak = val >= max && max != 0;
                                        return Expanded(
                                          child: Text(val.toStringAsFixed(2),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: isPeak ? Colors.red : Colors.black87,
                                                  fontWeight: isPeak ? FontWeight.bold : FontWeight.normal)),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showChannelCustomizationDialog() {
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDiaState) {
          return AlertDialog(
            title: const Text("Configure Graph Channels"),
            content: SizedBox(
                width: 300,
                height: 400,
                child: ListView.builder(
                    itemCount: _customizableChannels.length,
                    itemBuilder: (c, i) {
                      final ch = _customizableChannels[i];

                      Color col = Colors.black;
                      try {
                        final hex = (ch['Effective_GraphColor'] ?? '#000000').toString().replaceAll('#', '');
                        col = Color(int.parse('FF$hex', radix: 16));
                      } catch (e) {
                        col = Colors.black;
                      }

                      final String name = ch['ChannelName']?.toString() ?? 'Channel $i';

                      return ListTile(
                        leading: Checkbox(
                            value: ch['isVisible'],
                            activeColor: col,
                            onChanged: (v) => setDiaState(() => ch['isVisible'] = v)),
                        title: Text(name),
                        trailing: GestureDetector(
                          onTap: () async {
                            Color newCol = col;
                            await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                    content: SingleChildScrollView(
                                        child: ColorPicker(
                                            pickerColor: col,
                                            onColorChanged: (c) => newCol = c,
                                            enableAlpha: false)),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            setDiaState(() => ch['Effective_GraphColor'] =
                                            '#${newCol.value.toRadixString(16).substring(2).toUpperCase()}');
                                          },
                                          child: const Text("DONE"))
                                    ]));
                          },
                          child: CircleAvatar(backgroundColor: col, radius: 12),
                        ),
                      );
                    })),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text("APPLY"))
            ],
          );
        }));
  }
}