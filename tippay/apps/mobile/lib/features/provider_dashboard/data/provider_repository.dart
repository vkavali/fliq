import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository(ref.read(dioProvider));
});

class ProviderRepository {
  final Dio _dio;

  ProviderRepository(this._dio);

  Future<Map<String, dynamic>> getProviderTips({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      ApiConstants.providerTips,
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyQrCodes() async {
    final response = await _dio.get(ApiConstants.myQrCodes);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createQrCode({String? locationLabel}) async {
    final response = await _dio.post(ApiConstants.createQrCode, data: {
      'type': 'STATIC',
      if (locationLabel != null) 'locationLabel': locationLabel,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> requestPayout({
    required int amountPaise,
    String mode = 'IMPS',
  }) async {
    final response = await _dio.post(ApiConstants.requestPayout, data: {
      'amountPaise': amountPaise,
      'mode': mode,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayoutHistory({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      ApiConstants.payoutHistory,
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  // ===== Payment Links =====

  Future<Map<String, dynamic>> createPaymentLink({
    String? description,
    int? suggestedAmountPaise,
    bool? allowCustomAmount,
  }) async {
    final response = await _dio.post(ApiConstants.createPaymentLink, data: {
      if (description != null) 'description': description,
      if (suggestedAmountPaise != null) 'suggestedAmountPaise': suggestedAmountPaise,
      if (allowCustomAmount != null) 'allowCustomAmount': allowCustomAmount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyPaymentLinks() async {
    final response = await _dio.get(ApiConstants.myPaymentLinks);
    return response.data as List<dynamic>;
  }

  Future<void> deletePaymentLink(String id) async {
    await _dio.delete(ApiConstants.deletePaymentLink(id));
  }
}
