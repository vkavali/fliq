import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/badge_model.dart';
import '../../../shared/models/streak_model.dart';

final gamificationRepositoryProvider =
    Provider<GamificationRepository>((ref) {
  return GamificationRepository(ref.read(dioProvider));
});

class GamificationRepository {
  final Dio _dio;

  GamificationRepository(this._dio);

  Future<List<BadgeModel>> getBadges() async {
    final response = await _dio.get(ApiConstants.badges);
    final data = response.data as List;
    return data
        .map((e) => BadgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StreakModel> getStreak() async {
    final response = await _dio.get(ApiConstants.streak);
    return StreakModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({
    String type = 'tippers',
    String period = 'week',
  }) async {
    final endpoint = type == 'providers'
        ? ApiConstants.leaderboardProviders
        : ApiConstants.leaderboardTippers;
    final response = await _dio.get(
      endpoint,
      queryParameters: {'period': period},
    );
    return (response.data as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
