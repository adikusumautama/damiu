// lib/services/user_local_data_service.dart
import 'dart:convert';
import 'package:damiu/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service ini bertanggung jawab untuk menyimpan dan mengambil data UserModel
/// dari penyimpanan lokal perangkat (SharedPreferences).
class UserLocalDataService {
  static const _userKey = 'cached_user';

  /// Menyimpan data UserModel ke SharedPreferences sebagai string JSON.
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = {
      'uid': user.uid,
      'email': user.email,
      'name': user.name,
      'role': user.role,
      'phoneNumber': user.phoneNumber,
      'address': user.address,
    };
    await prefs.setString(_userKey, jsonEncode(userMap));
  }

  /// Mengambil UserModel dari SharedPreferences.
  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString == null) return null;

    final userMap = jsonDecode(userString) as Map<String, dynamic>;
    return UserModel.fromMap(userMap, userMap['uid']);
  }

  /// Menghapus cache pengguna saat logout.
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}

