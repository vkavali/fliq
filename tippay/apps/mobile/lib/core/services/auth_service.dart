import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../../shared/models/user_model.dart';

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? currentUser;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.currentUser,
  });

  bool get isLoggedIn => status == AuthStatus.authenticated && currentUser != null;

  AuthState copyWith({AuthStatus? status, UserModel? currentUser}) {
    return AuthState(
      status: status ?? this.status,
      currentUser: currentUser ?? this.currentUser,
    );
  }
}

// ---------------------------------------------------------------------------
// Auth service (StateNotifier)
// ---------------------------------------------------------------------------

class AuthService extends StateNotifier<AuthState> {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthService(this._dio, this._storage) : super(const AuthState());

  // ---- Public getters ----

  bool get isLoggedIn => state.isLoggedIn;
  UserModel? get currentUser => state.currentUser;

  // ---- Check persisted auth on app startup ----

  Future<void> checkAuth() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      // Validate the token by fetching the user profile from the backend
      final response = await _dio.get(ApiConstants.userProfile);
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      await _storage.saveUserData(user.toJson());
      state = AuthState(status: AuthStatus.authenticated, currentUser: user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired — try refresh
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          await checkAuth(); // retry with new token
          return;
        }
        // Refresh failed — force logout
        await logout();
      } else {
        // Network or server error — try to use cached user data
        final cached = await _storage.getUserData();
        if (cached != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            currentUser: UserModel.fromJson(cached),
          );
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      }
    }
  }

  // ---- OTP flow ----

  Future<void> sendOtp(String phone) async {
    await _dio.post(ApiConstants.sendOtp, data: {'phone': phone});
  }

  Future<UserModel> verifyOtp(String phone, String code) async {
    final response = await _dio.post(
      ApiConstants.verifyOtp,
      data: {'phone': phone, 'code': code},
    );
    final data = response.data as Map<String, dynamic>;

    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final userJson = data['user'] as Map<String, dynamic>;

    await _storage.saveAccessToken(accessToken);
    await _storage.saveRefreshToken(refreshToken);
    await _storage.saveUserData(userJson);

    final user = UserModel.fromJson(userJson);
    state = AuthState(status: AuthStatus.authenticated, currentUser: user);
    return user;
  }

  // ---- Refresh user profile from backend ----

  Future<UserModel?> refreshProfile() async {
    try {
      final response = await _dio.get(ApiConstants.userProfile);
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      await _storage.saveUserData(user.toJson());
      state = AuthState(status: AuthStatus.authenticated, currentUser: user);
      return user;
    } catch (_) {
      return state.currentUser;
    }
  }

  // ---- Logout ----

  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ---- Token refresh ----

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      // Use a separate Dio instance to avoid interceptor loops
      final plainDio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await plainDio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['accessToken'] as String;

      await _storage.saveAccessToken(newAccessToken);

      // If the backend also returns a rotated refresh token, save it
      if (data.containsKey('refreshToken')) {
        await _storage.saveRefreshToken(data['refreshToken'] as String);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

/// Convenience provider for quick login checks in widgets/guards.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isLoggedIn;
});

/// Convenience provider for the current user.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});
