// [UPDATE] lib/AdminService/input_type_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class InputTypeApiService {
  static String get baseUrl => ApiConstants.baseUrl;
  static const String endpoint = '/api_inputmaster.php';

  Future<List<Map<String, dynamic>>> getAllInputTypes() async {
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
          throw Exception(data['error'] ?? 'Failed to load input types');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // === Update Input Type Details ===
  Future<void> updateInputType({
    required int id,
    String? typeName,
    double? defaultMinRange,
    double? defaultMaxRange,
    int? defaultDecimalPlaces,
  }) async {
    final body = {
      'action': 'UPDATE',
      'InputTypeID': id,
    };

    if (typeName != null) body['TypeName'] = typeName;
    if (defaultMinRange != null) body['DefaultMinRange'] = defaultMinRange;
    if (defaultMaxRange != null) body['DefaultMaxRange'] = defaultMaxRange;
    if (defaultDecimalPlaces != null) body['DefaultDecimalPlaces'] = defaultDecimalPlaces;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] != 'success') {
          throw Exception(data['error'] ?? 'Failed to update input type.');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // === NEW METHOD: Create Input Type (For custom types) ===
  Future<void> createInputType({
    required String typeName,
    required bool isLinear,
    required double defaultMinRange,
    required double defaultMaxRange,
    int? defaultDecimalPlaces,
  }) async {
    final body = {
      'action': 'INSERT',
      'TypeName': typeName,
      'IsLinear': isLinear ? 1 : 0,
      'DefaultMinRange': defaultMinRange,
      'DefaultMaxRange': defaultMaxRange,
      'DefaultDecimalPlaces': defaultDecimalPlaces,
      // Note: InputTypeID will be assigned by the server (SP)
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] != 'success') {
          throw Exception(data['error'] ?? 'Failed to create input type.');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // === NEW METHOD: Delete Input Type (For custom types) ===
  Future<void> deleteInputType({required int id}) async {
    final body = {
      'action': 'DELETE',
      'InputTypeID': id,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] != 'success') {
          throw Exception(data['error'] ?? 'Failed to delete input type. Check if it\'s used by any channel.');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}