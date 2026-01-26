class ApiConstants {
  // === CONFIGURATION ===
  // Set this to true before building the release version
  static const bool production = true;

  // === BASE URLS ===
  static const String _liveUrl = "https://www.aquare.co.in/mobileAPI/countronAPI";

  // Local URL
  static const String _localUrl = "http://localhost/countrons";

  // Logic to switch between Live and Local
  static String get baseUrl {
    return production ? _liveUrl : _localUrl;
  }
}