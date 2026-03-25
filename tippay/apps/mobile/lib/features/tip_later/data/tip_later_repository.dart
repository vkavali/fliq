import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/deferred_tip_model.dart';

final tipLaterRepositoryProvider = Provider<TipLaterRepository>((ref) {
  return TipLaterRepository(ref.read(dioProvider));
});

class TipLaterRepository {
  final Dio _dio;

  TipLaterRepository(this._dio);

  Future<DeferredTipModel> createDeferredTip({
    required String providerId,
    required int amountPaise,
    String? message,
    int? rating,
  }) async {
    final response = await _dio.post('/tip-later', data: {
      'providerId': providerId,
      'amountPaise': amountPaise,
      if (message != null) 'message': message,
      if (rating != null) 'rating': rating,
    });
    return DeferredTipModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DeferredTipModel>> getMyDeferredTips() async {
    final response = await _dio.get('/tip-later/my');
    return (response.data as List<dynamic>)
        .map((e) => DeferredTipModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> payDeferredTip(String deferredTipId) async {
    final response = await _dio.post('/tip-later/$deferredTipId/pay');
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelDeferredTip(String deferredTipId) async {
    await _dio.delete('/tip-later/$deferredTipId');
  }
}
