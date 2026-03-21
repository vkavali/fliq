import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(secureStorageProvider));
});

class AuthRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthRepository(this._dio, this._storage);

  Future<void> sendOtp(String phone) async {
    await _dio.post(ApiConstants.sendOtp, data: {'phone': phone});
  }

  Future<UserModel> verifyOtp(String phone, String code) async {
    final response = await _dio.post(
      ApiConstants.verifyOtp,
      data: {'phone': phone, 'code': code},
    );
    final data = response.data as Map<String, dynamic>;

    await _storage.saveAccessToken(data['accessToken'] as String);
    await _storage.saveRefreshToken(data['refreshToken'] as String);
    await _storage.saveUserData(data['user'] as Map<String, dynamic>);

    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel?> getCurrentUser() async {
    final data = await _storage.getUserData();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
