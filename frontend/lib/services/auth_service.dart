import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const String _userKey = 'smartprep_auth_user';
  static const String _tokenKey = 'smartprep_auth_token';

  final ApiService _apiService = ApiService();

  Future<UserModel> login({
    required String username,
    required String accessKey,
  }) async {
    String token = '';
    String userId = username;
    String role = username.toLowerCase().contains('teacher') ? 'teacher' : 'student';

    try {
      // 1. Try calling the backend /test-token or login endpoint
      final response = await _apiService.dio.post(
        '/test-token',
        queryParameters: {'user_id': username},
      );

      if (response.statusCode == 200 && response.data != null) {
        token = response.data['access_token']?.toString() ?? '';
      }
    } on DioException catch (dioErr) {
      debugPrint('Backend connection notice: ${dioErr.message}');
      // Fallback dev token if backend is unreachable during frontend dev
      token = 'mock-jwt-token-for-$username';
    } catch (e) {
      debugPrint('Auth exception: $e');
      token = 'mock-jwt-token-for-$username';
    }

    if (token.isEmpty) {
      token = 'jwt-token-session-$username';
    }

    final user = UserModel(
      id: userId,
      username: username,
      name: username.replaceAll('_', ' ').toUpperCase(),
      role: role,
      token: token,
    );

    // Save token to API client
    _apiService.setAuthToken(token);

    // Persist to SharedPreferences
    await _saveUserSession(user);

    return user;
  }

  Future<void> _saveUserSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, user.token);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Failed to persist session: $e');
    }
  }

  Future<UserModel?> getStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);

      if (userJson != null && token != null) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        final user = UserModel.fromJson(data, token: token);
        _apiService.setAuthToken(token);
        return user;
      }
    } catch (e) {
      debugPrint('Failed to load stored session: $e');
    }
    return null;
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('Failed to clear session: $e');
    }
    _apiService.setAuthToken(null);
  }
}
