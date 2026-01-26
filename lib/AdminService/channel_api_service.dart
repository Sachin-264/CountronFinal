// [UPDATE] lib/AdminService/channel_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class ChannelApiService {
  static String get baseUrl => ApiConstants.baseUrl;
  static const String endpoint = '/api_channel_master.php';
  // --- NEW: Generate Channel ID ---
  Future<String> generateChannelId() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'GENERATEID'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Assuming the API returns { "ChannelID": "CH26" } directly or inside data
        if (data['ChannelID'] != null) {
          return data['ChannelID'].toString();
        } else if (data['data'] != null && data['data']['ChannelID'] != null) {
          // Fallback if wrapped in data object
          return data['data']['ChannelID'].toString();
        } else {
          return ''; // Return empty if format unexpected
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  // --------------------------------

  // Get all channels
  Future<List<Map<String, dynamic>>> getAllChannels() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'GETALL'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['error'] ?? 'Failed to load channels');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get single channel
  Future<Map<String, dynamic>> getChannel(int recNo) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'GET',
          'RecNo': recNo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          return data['data'][0];
        } else {
          throw Exception(data['error'] ?? 'Channel not found');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create channel
  // [UPDATED] Added required channelID parameter
  Future<Map<String, dynamic>> createChannel({
    required String channelID, // <--- NEW MANDATORY FIELD
    required String channelName,
    required String startingCharacter,
    required int dataLength,
    required int channelInputType,
    required int resolution,
    required String unit,
    required double lowLimits,
    required double highLimits,
    required String targetAlarmColour,
    required String graphLineColour,
    required double offset,
    double? lowValue,
    double? highValue,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'INSERT',
          'ChannelID': channelID, // <--- INCLUDED IN BODY
          'ChannelName': channelName,
          'StartingCharacter': startingCharacter,
          'DataLength': dataLength,
          'ChannelInputType': channelInputType,
          'Resolution': resolution,
          'Unit': unit,
          'LowLimits': lowLimits,
          'HighLimits': highLimits,
          'TargetAlarmColour': targetAlarmColour,
          'GraphLineColour': graphLineColour,
          'Offset': offset,
          'LowValue': lowValue,
          'HighValue': highValue,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          return data['data'][0];
        } else {
          throw Exception(data['error'] ?? 'Failed to create channel');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update channel
  Future<Map<String, dynamic>> updateChannel({
    required int recNo,
    String? channelName,
    String? startingCharacter,
    int? dataLength,
    int? channelInputType,
    int? resolution,
    String? unit,
    double? lowLimits,
    double? highLimits,
    String? targetAlarmColour,
    String? graphLineColour,
    double? offset,
    double? lowValue,
    double? highValue,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'action': 'UPDATE',
        'RecNo': recNo,
      };

      if (channelName != null) body['ChannelName'] = channelName;
      if (startingCharacter != null) body['StartingCharacter'] = startingCharacter;
      if (dataLength != null) body['DataLength'] = dataLength;
      if (unit != null) body['Unit'] = unit;
      if (targetAlarmColour != null) body['TargetAlarmColour'] = targetAlarmColour;
      if (graphLineColour != null) body['GraphLineColour'] = graphLineColour;
      if (channelInputType != null) body['ChannelInputType'] = channelInputType;
      if (resolution != null) body['Resolution'] = resolution;
      if (lowLimits != null) body['LowLimits'] = lowLimits;
      if (highLimits != null) body['HighLimits'] = highLimits;
      if (offset != null) body['Offset'] = offset;
      if (lowValue != null) body['LowValue'] = lowValue;
      if (highValue != null) body['HighValue'] = highValue;

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          return data['data'][0];
        } else {
          throw Exception(data['error'] ?? 'Failed to update channel');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

// [UPDATE] lib/AdminService/channel_api_service.dart

  // ... (rest of the class)

  // === UPDATED: Delete channel with Specific Error Parsing ===
  Future<void> deleteChannel(int recNo) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'DELETE',
          'RecNo': recNo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 1. Check for success
        if (data['status'] == 'success') {
          return;
        }

        // 2. Check for Specific SQL Reference Error (Nested in data list)
        // Structure: { "data": [ { "status": "sql_error", "error_message": "...REFERENCE constraint..." } ] }
        if (data['data'] is List && data['data'].isNotEmpty) {
          final firstError = data['data'][0];
          if (firstError is Map<String, dynamic>) {
            final String errorMsg = firstError['error_message']?.toString() ?? '';

            if (errorMsg.contains('REFERENCE constraint') ||
                errorMsg.contains('FK__') ||
                errorMsg.contains('conflicted with the REFERENCE')) {
              throw Exception('This channel already link to device so we cannot delete this');
            }
          }
        }

        // 3. Fallback for other errors
        throw Exception(data['error'] ?? 'Failed to delete channel');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
