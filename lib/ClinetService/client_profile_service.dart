import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class ClientProfileService {
  // Update this URL to match your server
  static String get baseUrl => "${ApiConstants.baseUrl}/api_client.php";

  Future<bool> updateClientProfile({
    required int recNo, // Maps to UserID
    required String username, // Required by PHP logic
    String? password,
    String? displayName, // Maps to CompanyName
    String? address,
    String? email,
    String? logoPath,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "action": "UPDATE",
        "RecNo": recNo,
        "Username": username,
        // Map Flutter fields to PHP parameters
        "CompanyName": displayName,
        "CompanyAddress": address,
        "ContactEmail": email,
        "LogoPath": logoPath,
      };

      // Only add password if user typed one
      if (password != null && password.isNotEmpty) {
        body["PasswordHash"] = password;
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['status'] == 'success';
      }
      return false;
    } catch (e) {
      print("Error updating profile: $e");
      return false;
    }
  }
}