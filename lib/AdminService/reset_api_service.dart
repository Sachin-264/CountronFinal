import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class ResetApiService {
  // Update this URL to match your server configuration
  static String get baseUrl => ApiConstants.baseUrl;
  static const String endpoint = '/reset_api.php';

  Future<void> resetPassword({
    required String targetType, // 'ADMIN' or 'CLIENT'
    required int recNo,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'RESET_PASSWORD',
          'TargetType': targetType,
          'RecNo': recNo,
          'NewPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return; // Success
        } else {
          throw Exception(data['error'] ?? 'Failed to reset password');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}