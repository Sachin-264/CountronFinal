// [REPLACE] lib/AdminService/client_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class ClientApiService {
  static String get baseUrl => ApiConstants.baseUrl;
  static const String _clientEndpoint = '/api_client.php';
  static const String _deviceEndpoint = '/api_devices.php';
  static const String _mapEndpoint = '/api_device_channel_map.php';
  static const String _channelEndpoint = '/api_channel_master.php';

  // Helper to handle response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        // NOTE: The 'data' field can be a list (GETALL) or an object (UPDATE).
        return data['data'];
      } else {
        throw Exception(data['error'] ?? 'API error');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<int> getDeviceChannelLimit(int deviceRecNo) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'GETLIMIT',
        'RecNo': deviceRecNo,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        // Return the limit (default to 0 if null)
        return data['data']['ClientChannelLimit'] ?? 0;
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch limit');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<bool> updateDeviceChannelLimit({
    required int recNo,
    required int limit,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'UPDATELIMIT',
        'RecNo': recNo,
        'ClientChannelLimit': limit,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'success';
    }
    return false;
  }



  // 1. Get all clients (FIXED: Added data transformation)
  Future<List<Map<String, dynamic>>> getAllClients() async {
    final response = await http.post(
      Uri.parse('$baseUrl$_clientEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'GETALL_CLIENTS'}),
    );

    // Original response body is List<dynamic> containing Map<String, dynamic>
    final List<dynamic> rawClients = _handleResponse(response);

    // --- CRITICAL FIX START ---
    return rawClients.map((client) {
      final Map<String, dynamic> clientMap = client as Map<String, dynamic>;

      // Check if 'IsActive' exists and is a boolean. If so, convert true/false to 1/0.
      if (clientMap['IsActive'] is bool) {
        clientMap['IsActive'] = (clientMap['IsActive'] == true) ? 1 : 0;
      }

      return clientMap;
    }).toList();
    // --- CRITICAL FIX END ---
  }

  // 2. Add new client
  Future<Map<String, dynamic>> createClient({
    required int adminRecNo,
    required String username,
    required String passwordHash,
    required String companyName,
    String? companyAddress,
    String? logoPath,
    String? contactEmail,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_clientEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'INSERT',
        'AdminRecNo': adminRecNo,
        'Username': username,
        'PasswordHash': passwordHash,
        'CompanyName': companyName,
        'CompanyAddress': companyAddress,
        'LogoPath': logoPath,
        'ContactEmail': contactEmail,
        'IsActive': 1,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  // 3. Edit client info
  Future<Map<String, dynamic>> updateClientInfo({
    required int recNo,
    String? companyName,
    String? companyAddress,
    String? logoPath,
    String? contactEmail,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_clientEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'UPDATE',
        'RecNo': recNo,
        'CompanyName': companyName,
        'CompanyAddress': companyAddress,
        'LogoPath': logoPath,
        'ContactEmail': contactEmail,
      }),
    );
    return (_handleResponse(response) as List).first;
  }



  Future<Map<String, dynamic>> resetClientPassword({
    required int recNo,
    required String newPasswordHash,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_clientEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'UPDATE',
        'RecNo': recNo,
        'PasswordHash': newPasswordHash,
      }),
    );
    return (_handleResponse(response) as List).first;
  }



  Future<Map<String, dynamic>> setClientActiveStatus({
    required int recNo,
    required bool isActive,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_clientEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'UPDATE',
        'RecNo': recNo,
        'IsActive': isActive ? 1 : 0,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  // 6. Check Username
  Future<bool> checkUsernameExists(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_clientEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'CHECK_USERNAME',
        'Username': username,
      }),
    );
    final data = _handleResponse(response);
    return (data[0]['exists'] == 1);
  }



  // UPDATED: Get devices by client with new nested structure
  Future<Map<String, dynamic>> getDevicesByClient(int clientRecNo) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'GETBYCLIENT',
        'ClientRecNo': clientRecNo,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        // Return the full response with devices and channels structure
        return {
          'devices': List<Map<String, dynamic>>.from(data['devices']['data']),
          'channels': List<Map<String, dynamic>>.from(data['channels']['data']),
        };
      } else {
        throw Exception(data['error'] ?? 'API error');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

// Fetch the next available RecNo for a new device
  Future<int> getNextDeviceRecNo() async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'GETNEXTID'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['next_recno'] as int;
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch next ID');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  // Update registerDevice to accept the generated RecNo
  Future<Map<String, dynamic>> registerDevice({
    required int recNo, // Pass the generated ID here
    required int clientRecNo,
    required String deviceName,
    required String serialNumber,
    required int channelsCount,
    String? location,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'INSERT',
        'RecNo': recNo, // Now sending the manually generated ID
        'ClientRecNo': clientRecNo,
        'DeviceName': deviceName,
        'SerialNumber': serialNumber,
        'ChannelsCount': channelsCount,
        'Location': location,
        'IsActive': 1,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  Future<Map<String, dynamic>> updateDevice({
    required int recNo,
    String? deviceName,
    String? serialNumber,
    int? channelsCount,
    String? location,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'UPDATE',
        'RecNo': recNo,
        'DeviceName': deviceName,
        'SerialNumber': serialNumber,
        'ChannelsCount': channelsCount,
        'Location': location,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  Future<Map<String, dynamic>> setDeviceActiveStatus({
    required int recNo,
    required bool isActive,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_deviceEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'DELETE',
        'RecNo': recNo,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  // ==========================================================
  // === 3. DEVICE-CHANNEL MAPPING (api_device_channel_map.php) ===
  // ==========================================================

  Future<List<Map<String, dynamic>>> getChannelsForDevice(int deviceRecNo) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_mapEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'GETBYDEVICE',
        'DeviceRecNo': deviceRecNo,
      }),
    );
    return List<Map<String, dynamic>>.from(_handleResponse(response));
  }

  Future<Map<String, dynamic>> assignChannelToDevice({
    required int deviceRecNo,
    required int channelRecNo,
    required int channelIndex,
    bool isEnabled = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_mapEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'INSERT',
        'DeviceRecNo': deviceRecNo,
        'ChannelRecNo': channelRecNo,
        'ChannelIndex': channelIndex,
        'IsEnabled': isEnabled ? 1 : 0,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  Future<Map<String, dynamic>> updateAssignedChannel({
    required int recNo,
    int? channelRecNo,
    int? channelIndex,
    bool? isEnabled,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_mapEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'UPDATE',
        'RecNo': recNo,
        'ChannelRecNo': channelRecNo,
        'ChannelIndex': channelIndex,
        'IsEnabled': isEnabled != null ? (isEnabled ? 1 : 0) : null,
      }),
    );
    return (_handleResponse(response) as List).first;
  }

  Future<void> removeChannelFromDevice(int recNo) async {
    final response = await http.post(
      Uri.parse('$baseUrl$_mapEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'DELETE',
        'RecNo': recNo,
      }),
    );
    _handleResponse(response);
  }

  // ==========================================================
  // === 4. CHANNEL LIST (api_channel_master.php) ===
  // ==========================================================

  Future<List<Map<String, dynamic>>> getAllChannels() async {
    final response = await http.post(
      Uri.parse('$baseUrl$_channelEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'GETALL'}),
    );
    return List<Map<String, dynamic>>.from(_handleResponse(response));
  }
}