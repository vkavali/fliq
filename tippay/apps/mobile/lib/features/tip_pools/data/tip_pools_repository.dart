import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

final tipPoolsRepositoryProvider = Provider<TipPoolsRepository>((ref) {
  return TipPoolsRepository(ref.read(dioProvider));
});

class TipPoolsRepository {
  final Dio _dio;

  TipPoolsRepository(this._dio);

  Future<Map<String, dynamic>> createPool({
    required String name,
    String? description,
    required String splitMethod,
  }) async {
    final response = await _dio.post(ApiConstants.tipPools, data: {
      'name': name,
      'splitMethod': splitMethod,
      if (description != null) 'description': description,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyPools() async {
    final response = await _dio.get(ApiConstants.myTipPools);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPoolDetail(String poolId) async {
    final response = await _dio.get(ApiConstants.tipPoolDetail(poolId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMember(
    String poolId, {
    required String phone,
    String? role,
    double? splitPercentage,
  }) async {
    final response = await _dio.post(ApiConstants.tipPoolMembers(poolId), data: {
      'phone': phone,
      if (role != null) 'role': role,
      if (splitPercentage != null) 'splitPercentage': splitPercentage,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeMember(String poolId, String memberId) async {
    await _dio.delete(ApiConstants.tipPoolRemoveMember(poolId, memberId));
  }

  Future<Map<String, dynamic>> updatePool(
    String poolId, {
    String? name,
    String? description,
    String? splitMethod,
  }) async {
    final response = await _dio.patch(ApiConstants.tipPoolDetail(poolId), data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (splitMethod != null) 'splitMethod': splitMethod,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> deactivatePool(String poolId) async {
    await _dio.delete(ApiConstants.tipPoolDetail(poolId));
  }

  Future<Map<String, dynamic>> getPoolEarnings(String poolId) async {
    final response = await _dio.get(ApiConstants.tipPoolEarnings(poolId));
    return response.data as Map<String, dynamic>;
  }
}
