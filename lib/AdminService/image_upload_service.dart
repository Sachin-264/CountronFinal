import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io';

class ImageUploadService {
  static const String _imageUploadUrl = "https://www.aquare.co.in/mobileAPI/sachin/photogcp1.php";
  static const String imageBaseUrl = "https://storage.googleapis.com/upload-images-34/images/LMS/";

  static String getFullLogoUrl(String? path) {
    if (path == null || path.isEmpty) {
      return '';
    }
    return imageBaseUrl.replaceAll('{pathofphoto}', path);
  }

  Future<String> uploadClientLogo(Uint8List imageBytes, String clientName) async {
    print("🚀 [uploadClientLogo] Starting logo upload for: $clientName");
    final stopwatch = Stopwatch()..start();

    try {
      // Bytes encoded to base64
      String base64Image = base64Encode(imageBytes);
      print("🖼 [uploadClientLogo] Image encoded to base64.");

      final payload = {
        'userID': 1,
        'groupCode': 1,
        'imageType': 'LMS',
        'stationImages': [base64Image],
        'str': clientName
      };

      final url = Uri.parse(_imageUploadUrl);
      print("📤 [uploadClientLogo] Sending POST request to: $url");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 90)); // <--- CHANGED FROM 30 TO 90 SECONDS

      stopwatch.stop();
      print("✅ [uploadClientLogo] Response. Status: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms");

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final errorObject = responseBody['error'];

        if (errorObject != null && errorObject['code'] == 200) {
          final stationUploads = responseBody['stationUploads'] as List<dynamic>?;
          if (stationUploads != null && stationUploads.isNotEmpty) {
            final String uniqueFileName = stationUploads[0]['UniqueFileName'];
            print("✅ [uploadClientLogo] Success! Filename: $uniqueFileName");
            return uniqueFileName;
          } else {
            throw Exception("API success but no image path returned.");
          }
        } else {
          final errorMessage = errorObject?['message'] ?? 'Unknown API error';
          throw Exception("API failure: $errorMessage");
        }
      } else {
        throw HttpException('Server error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('Network Error: Check internet/CORS. $e');
    } on TimeoutException catch (e) {
      // Customized timeout message
      throw Exception('Upload timed out (Server took too long). Try a smaller image or check your connection.');
    } catch (e) {
      throw Exception('Failed to upload logo: $e');
    }
  }
}