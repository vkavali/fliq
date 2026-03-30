import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class EkycInitiateResult {
  final String sessionToken;
  final String maskedPhone;

  const EkycInitiateResult({
    required this.sessionToken,
    required this.maskedPhone,
  });

  factory EkycInitiateResult.fromJson(Map<String, dynamic> json) =>
      EkycInitiateResult(
        sessionToken: json['sessionToken'] as String,
        maskedPhone: json['maskedPhone'] as String,
      );
}

class EkycProfile {
  final String name;
  final String dob;
  final String gender;
  final String address;

  const EkycProfile({
    required this.name,
    required this.dob,
    required this.gender,
    required this.address,
  });

  factory EkycProfile.fromJson(Map<String, dynamic> json) => EkycProfile(
        name: json['name'] as String? ?? '',
        dob: json['dob'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );
}

class EkycStatus {
  final bool kycVerified;
  final String? kycMethod;
  final String? kycCompletedAt;
  final String kycStatus;

  const EkycStatus({
    required this.kycVerified,
    required this.kycMethod,
    required this.kycCompletedAt,
    required this.kycStatus,
  });

  factory EkycStatus.fromJson(Map<String, dynamic> json) => EkycStatus(
        kycVerified: json['kycVerified'] as bool? ?? false,
        kycMethod: json['kycMethod'] as String?,
        kycCompletedAt: json['kycCompletedAt'] as String?,
        kycStatus: json['kycStatus'] as String? ?? 'PENDING',
      );
}

class EkycRepository {
  final Dio _dio;

  EkycRepository(this._dio);

  Future<EkycInitiateResult> initiateEkyc(String aadhaarOrVid) async {
    final response = await _dio.post(
      '/ekyc/initiate',
      data: {'aadhaarOrVid': aadhaarOrVid},
    );
    return EkycInitiateResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({bool success, EkycProfile profile})> verifyOtp({
    required String sessionToken,
    required String otp,
  }) async {
    final response = await _dio.post(
      '/ekyc/verify-otp',
      data: {'sessionToken': sessionToken, 'otp': otp},
    );
    final data = response.data as Map<String, dynamic>;
    return (
      success: data['success'] as bool? ?? false,
      profile: EkycProfile.fromJson(data['profile'] as Map<String, dynamic>),
    );
  }

  Future<EkycStatus> getStatus() async {
    final response = await _dio.get('/ekyc/status');
    return EkycStatus.fromJson(response.data as Map<String, dynamic>);
  }
}

final ekycRepositoryProvider = Provider<EkycRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return EkycRepository(dio);
});
