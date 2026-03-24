import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

final tipsRepositoryProvider = Provider<TipsRepository>((ref) {
  return TipsRepository(ref.read(dioProvider));
});

class CreateTipResponse {
  final String tipId;
  final String orderId;
  final int amount;
  final String currency;
  final String razorpayKeyId;
  final String providerName;
  final String providerCategory;

  CreateTipResponse({
    required this.tipId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.razorpayKeyId,
    required this.providerName,
    required this.providerCategory,
  });

  factory CreateTipResponse.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>? ?? {};
    return CreateTipResponse(
      tipId: json['tipId'] as String,
      orderId: json['orderId'] as String,
      amount: json['amount'] as int,
      currency: json['currency'] as String? ?? 'INR',
      razorpayKeyId: json['razorpayKeyId'] as String,
      providerName: provider['name'] as String? ?? '',
      providerCategory: provider['category'] as String? ?? '',
    );
  }
}

class TipsRepository {
  final Dio _dio;

  TipsRepository(this._dio);

  Future<CreateTipResponse> createTip({
    required String providerId,
    required int amountPaise,
    required String source,
    String? message,
    int? rating,
  }) async {
    final response = await _dio.post(ApiConstants.createTip, data: {
      'providerId': providerId,
      'amountPaise': amountPaise,
      'source': source,
      if (message != null) 'message': message,
      if (rating != null) 'rating': rating,
    });
    return CreateTipResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> verifyPayment({
    required String tipId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await _dio.post(ApiConstants.verifyTipPayment(tipId), data: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
  }

  Future<Map<String, dynamic>> resolveQrCode(String qrCodeId) async {
    final response = await _dio.get(ApiConstants.resolveQrCode(qrCodeId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerTips({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      ApiConstants.customerTips,
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProviderPublic(String providerId) async {
    final response = await _dio.get(ApiConstants.providerPublic(providerId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchProviders({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      ApiConstants.searchProviders,
      queryParameters: {
        'q': query,
        if (category != null) 'category': category,
        'page': page,
        'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
