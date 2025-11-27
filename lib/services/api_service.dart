import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'HistoryModel.dart';

class ApiService {
  String _baseUrl = 'https://techdotbit.in/api'; // Default global base
  /// Load tenant URL if already saved
  Future<void> loadTenantBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl =
        prefs.getString('tenant_base_url') ?? 'https://techdotbit.in/api';
  }

  /// Save tenant-specific base URL (from domain_check)
  Future<void> setTenantBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    // Ensure clean format like: https://savit.techdotbit.in/api
    String apiUrl = baseUrl.endsWith('/api') ? baseUrl : '$baseUrl/api';
    await prefs.setString('tenant_base_url', apiUrl);
    await prefs.setString('base_url', baseUrl);
    _baseUrl = apiUrl;
  }

  /// Get token from local storage
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Save token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// DOMAIN CHECK (always calls master domain)
  Future<Map<String, dynamic>> checkDomain(String domain) async {
    final res = await http.post(
      Uri.parse('https://techdotbit.in/api/domain_check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'domain': domain}),
    );

    final data = jsonDecode(res.body);
    if (data['success'] == true && data['data']['base_url'] != null) {
      await setTenantBaseUrl(data['data']['base_url']);
    }
    return data;
  }

  /// LOGIN
  Future<Map<String, dynamic>> login(String email, String password) async {
    await loadTenantBaseUrl();
    final res = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
     print(res.toString());
    final data = jsonDecode(res.body);

    if (data['success'] == true) {
      await _saveToken(data['data']['token']);
    }
    return data;
  }

  /// LOGOUT
  Future<void> logout() async {
    await loadTenantBaseUrl();
    final token = await _getToken();
    if (token == null) return;

    await http.post(
      Uri.parse('$_baseUrl/logout'),
      headers: {'Authorization': token},
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  /// CHECK-IN
  Future<Map<String, dynamic>> checkin(double lat, double lng) async {
    await loadTenantBaseUrl();
    final token = await _getToken();

    final res = await http.post(
      Uri.parse('$_baseUrl/checkin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> storeelocation({
    required List<Map<String, dynamic>> payload,
  }) async {
    try {
      await loadTenantBaseUrl(); // ✅ Ensure base URL is loaded
      final token = await _getToken(); // ✅ Get auth token

      final url = Uri.parse('$_baseUrl/storemulti_tracking');
      print(url);
      // ✅ Proper JSON encode for wrapped "locations" array
      final body = jsonEncode({'locations': payload});

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': ?token},
        body: body, // ✅ Send wrapped body, not payload directly
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('✅ storeelocation success: ${res.body}');
        return jsonDecode(res.body);
      } else {
        debugPrint(
          '⚠️ storeelocation API error: ${res.statusCode} ${res.body}',
        );
        return {'success': false, 'message': 'Server Error: ${res.statusCode}'};
      }
    } catch (e) {
      debugPrint('❌ storeelocation upload failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> storelocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
    String? deviceId,
  }) async {
    try {
      await loadTenantBaseUrl(); // ✅ Ensure base URL is loaded
      final token = await _getToken(); // ✅ Get auth token

      // Build payload
      final data = {
        'lat': latitude.toString(),
        'long': longitude.toString(),
        if (accuracy != null) 'accuracy': accuracy.toString(),
        if (address != null) 'address': address,
        if (deviceId != null) 'device_id': deviceId,
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/store_tracking'),
        headers: {
          'Accept': 'application/json',
          'Authorization': '$token ', // ✅ Add Bearer prefix
        },
        body: data,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        debugPrint('Tracking API error: ${res.body}');
        return {'success': false, 'message': 'Server Error: ${res.statusCode}'};
      }
    } catch (e) {
      debugPrint('Tracking upload failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<double> calculateTotalDistanceFromHistory(
    List<Map<String, dynamic>> locations,
  ) async {
    double total = 0.0;

    for (int i = 0; i < locations.length - 1; i++) {
      final start = locations[i];
      final end = locations[i + 1];

      final double distance = Geolocator.distanceBetween(
        double.parse(start['latitude'].toString()),
        double.parse(start['longitude'].toString()),
        double.parse(end['latitude'].toString()),
        double.parse(end['longitude'].toString()),
      );

      total += distance;
    }

    return total / 1000; // convert to kilometers
  }

  Future<Map<String, dynamic>> getCurrentStatus() async {
    await loadTenantBaseUrl();
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/currentstatus/'),
      headers: {'Accept': 'application/json', 'Authorization': token ?? ''},
    );
    return jsonDecode(res.body);
  }

  /// PROFILE API
  Future<Map<String, dynamic>> getProfile() async {
    try {
      await loadTenantBaseUrl(); // ✅ Ensure correct tenant base
      final token = await _getToken(); // ✅ Get stored token

      final url = Uri.parse('$_baseUrl/profile');

      final res = await http.get(
        url,
        headers: {'Accept': 'application/json', 'Authorization': token ?? ''},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        debugPrint('Profile API error: ${res.statusCode} ${res.body}');
        return {'success': false, 'message': 'Server Error: ${res.statusCode}'};
      }
    } catch (e) {
      debugPrint('❌ Profile API failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// CHECK-OUT
  Future<Map<String, dynamic>> checkout(double lat, double lng) async {
    await loadTenantBaseUrl();
    final token = await _getToken();

    final res = await http.post(
      Uri.parse('$_baseUrl/checkout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    print(res.body.toString());
    return jsonDecode(res.body);
  }

  /*Future<List<dynamic>> getAttendanceHistory() async {
    await loadTenantBaseUrl();
    final token = await _getToken();

    final res = await http.get(
      Uri.parse('$_baseUrl/attendance_history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );

    final Map<String, dynamic> data = jsonDecode(res.body);
    if (data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message']);
    }
  }*/
  Future<HistoryModel> getAttendanceHistory() async {
    await loadTenantBaseUrl();
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/attendance_history');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': ?token, // if needed
      },
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      return HistoryModel.fromJson(jsonData);
    } else {
      throw Exception('Failed to load attendance history');
    }
  }

  Future<Map<String, dynamic>> getTrackingHistory({String? date}) async {
    try {
      await loadTenantBaseUrl();
      final token = await _getToken();

      final url = Uri.parse(
        date == null
            ? '$_baseUrl/tracking-history'
            : '$_baseUrl/tracking-history?date=$date',
      );

      final res = await http.get(
        url,
        headers: {'Accept': 'application/json', 'Authorization': token ?? ''},
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        return {'success': false, 'message': 'Server Error: ${res.statusCode}'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load tracking history: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getDirectionRoute({required String date}) async {
    try {
      await loadTenantBaseUrl();
      final token = await _getToken();
      //   String  date="2025-10-29";
      final url = Uri.parse('$_baseUrl/directionroute?date=$date');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json', 'Authorization': token ?? ''},
      );
      print(response.body.toString());
      // Check response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching direction route: $e',
      };
    }
  }
}
