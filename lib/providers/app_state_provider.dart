import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  
  String? _geminiApiKey;
  String? _currentCommand;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  String _sttLanguage = 'id_ID'; // Default Indonesian
  
  AppStateProvider(this.prefs) {
    _loadSettings();
  }
  
  // Getters
  String? get geminiApiKey => _geminiApiKey;
  String? get currentCommand => _currentCommand;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get locationName => _locationName;
  String get sttLanguage => _sttLanguage;
  
  bool get hasApiKey => _geminiApiKey != null && _geminiApiKey!.isNotEmpty;
  bool get hasLocation => _latitude != null && _longitude != null;
  
  // Load settings from SharedPreferences
  void _loadSettings() {
    _geminiApiKey = prefs.getString('gemini_api_key');
    _latitude = prefs.getDouble('latitude');
    _longitude = prefs.getDouble('longitude');
    _locationName = prefs.getString('location_name');
    _sttLanguage = prefs.getString('stt_language') ?? 'id_ID';
    notifyListeners();
  }
  
  // Save Gemini API Key
  Future<void> saveGeminiApiKey(String apiKey) async {
    await prefs.setString('gemini_api_key', apiKey);
    _geminiApiKey = apiKey;
    notifyListeners();
  }
  
  // Set current voice command
  void setCurrentCommand(String command) {
    _currentCommand = command;
    notifyListeners();
  }
  
  // Clear current command
  void clearCurrentCommand() {
    _currentCommand = null;
    notifyListeners();
  }
  
  // Save location
  Future<void> saveLocation(double lat, double lng, String name) async {
    await prefs.setDouble('latitude', lat);
    await prefs.setDouble('longitude', lng);
    await prefs.setString('location_name', name);
    _latitude = lat;
    _longitude = lng;
    _locationName = name;
    notifyListeners();
  }
  
  // Clear location
  Future<void> clearLocation() async {
    await prefs.remove('latitude');
    await prefs.remove('longitude');
    await prefs.remove('location_name');
    _latitude = null;
    _longitude = null;
    _locationName = null;
    notifyListeners();
  }
  
  // Save STT Language
  Future<void> saveSttLanguage(String languageCode) async {
    await prefs.setString('stt_language', languageCode);
    _sttLanguage = languageCode;
    notifyListeners();
  }
}