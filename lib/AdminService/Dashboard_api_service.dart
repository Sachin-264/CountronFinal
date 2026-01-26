// [CREATE] lib/AdminService/dashboard_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class DashboardApiService {
  static  String baseUrl = ApiConstants.baseUrl;
  static const String _dashboardEndpoint = '/api_dashboard.php';

  Future<Map<String, dynamic>> getDashboardData(int adminRecNo) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$_dashboardEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'AdminRecNo': adminRecNo}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'API error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load dashboard data: $e');
    }
  }
}
