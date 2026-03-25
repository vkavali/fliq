import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/tip_jar_model.dart';

final tipJarsRepositoryProvider = Provider<TipJarsRepository>((ref) {
  return TipJarsRepository(ref.read(dioProvider));
});

class TipJarsRepository {
  final Dio _dio;

  TipJarsRepository(this._dio);

  Future<TipJarModel> createJar({
    required String name,
    required String eventType,
    String? description,
    String? expiresAt,
    int? targetAmountPaise,
  }) async {
    final response = await _dio.post('/tip-jars', data: {
      'name': name,
      'eventType': eventType,
      if (description != null) 'description': description,
      if (expiresAt != null) 'expiresAt': expiresAt,
      if (targetAmountPaise != null) 'targetAmountPaise': targetAmountPaise,
    });
    return TipJarModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getMyJars() async {
    final response = await _dio.get('/tip-jars/my');
    return response.data as Map<String, dynamic>;
  }

  Future<TipJarModel> resolveJar(String shortCode) async {
    final response = await _dio.get('/tip-jars/resolve/$shortCode');
    return TipJarModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TipJarModel> getJarById(String jarId) async {
    final response = await _dio.get('/tip-jars/$jarId');
    return TipJarModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TipJarMemberModel> addMember({
    required String jarId,
    required String providerId,
    required double splitPercentage,
    String? roleLabel,
  }) async {
    final response = await _dio.post('/tip-jars/$jarId/members', data: {
      'providerId': providerId,
      'splitPercentage': splitPercentage,
      if (roleLabel != null) 'roleLabel': roleLabel,
    });
    return TipJarMemberModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeMember(String jarId, String memberId) async {
    await _dio.delete('/tip-jars/$jarId/members/$memberId');
  }

  Future<TipJarModel> updateSplits(
    String jarId,
    List<Map<String, dynamic>> splits,
  ) async {
    final response = await _dio.patch('/tip-jars/$jarId/splits', data: {'splits': splits});
    return TipJarModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> closeJar(String jarId) async {
    await _dio.delete('/tip-jars/$jarId');
  }

  Future<Map<String, dynamic>> getJarStats(String jarId) async {
    final response = await _dio.get('/tip-jars/$jarId/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createJarTip({
    required String shortCode,
    required int amountPaise,
    String? message,
    int? rating,
    bool authenticated = true,
  }) async {
    final path = authenticated
        ? '/tip-jars/$shortCode/tip/authenticated'
        : '/tip-jars/$shortCode/tip';
    final response = await _dio.post(path, data: {
      'amountPaise': amountPaise,
      if (message != null) 'message': message,
      if (rating != null) 'rating': rating,
    });
    return response.data as Map<String, dynamic>;
  }
}
