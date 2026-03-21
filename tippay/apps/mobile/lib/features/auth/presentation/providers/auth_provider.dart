import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../shared/models/user_model.dart';

enum AuthStatus { initial, loading, otpSent, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState());

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.sendOtp(phone);
      state = state.copyWith(status: AuthStatus.otpSent);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> verifyOtp(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repo.verifyOtp(phone, code);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> checkAuth() async {
    final user = await _repo.getCurrentUser();
    if (user != null) {
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
