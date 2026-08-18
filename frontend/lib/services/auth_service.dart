import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// AuthService — wires directly to the FastAPI backend:
///   POST /auth/login          → token
///   GET  /auth/me             → user profile
///   POST /auth/student/register
///   POST /auth/mentor/register
class AuthService {
  static const String _userKey = 'smartprep_auth_user';
  static const String _tokenKey = 'smartprep_auth_token';

  final ApiService _apiService = ApiService();

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final token = response.data['access_token'] as String;
    _apiService.setAuthToken(token);

    // Fetch profile
    final meRes = await _apiService.dio.get('/auth/me');
    final user = UserModel.fromJson(meRes.data, token: token);

    _apiService.setAuthToken(token);
    await _saveUserSession(user);
    return user;
  }

  // ── Restore stored session ────────────────────────────────────────────────
  Future<UserModel?> getStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);
      if (userJson != null && token != null && token.isNotEmpty) {
        final data = jsonDecode(userJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(data, token: token);
        _apiService.setAuthToken(token);
        return user;
      }
    } catch (e) {
      debugPrint('Failed to restore session: $e');
    }
    return null;
  }

  // ── Logout ────────────────────────────────────────────────────────────────
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

  // ── Register student ──────────────────────────────────────────────────────
  Future<void> registerStudent(Map<String, dynamic> body) async {
    await _apiService.dio.post('/auth/student/register', data: body);
  }

  // ── Register mentor ───────────────────────────────────────────────────────
  Future<void> registerMentor(Map<String, dynamic> body) async {
    await _apiService.dio.post('/auth/mentor/register', data: body);
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  Future<void> _saveUserSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, user.token);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Failed to persist session: $e');
    }
  }
}
