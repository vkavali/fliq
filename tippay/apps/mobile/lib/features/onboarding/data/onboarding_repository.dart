import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.read(dioProvider));
});

class OnboardingRepository {
  final Dio _dio;

  OnboardingRepository(this._dio);

  /// Step 1 — Create provider profile (upgrades user to PROVIDER).
  Future<Map<String, dynamic>> createProfile({
    required String displayName,
    required String category,
    String? bio,
    String? upiVpa,
  }) async {
    final response = await _dio.post(ApiConstants.providerProfile, data: {
      'displayName': displayName,
      'category': category,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      if (upiVpa != null && upiVpa.isNotEmpty) 'upiVpa': upiVpa,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Step 2 — Save bank details (stored encrypted on backend).
  Future<void> saveBankDetails({
    required String upiVpa,
    required String bankAccountNumber,
    required String ifscCode,
    required String pan,
  }) async {
    await _dio.patch(ApiConstants.providerProfile, data: {
      'upiVpa': upiVpa,
      'bankAccountNumber': bankAccountNumber,
      'ifscCode': ifscCode,
      'pan': pan,
    });
  }

  /// Get own provider profile (includes KYC status via user relation).
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get(ApiConstants.providerProfile);
    return response.data as Map<String, dynamic>;
  }

  /// Step 4 — Generate a QR code.
  Future<Map<String, dynamic>> generateQrCode({String? locationLabel}) async {
    final response = await _dio.post(ApiConstants.createQrCode, data: {
      'type': 'STATIC',
      if (locationLabel != null && locationLabel.isNotEmpty)
        'locationLabel': locationLabel,
    });
    return response.data as Map<String, dynamic>;
  }
}
