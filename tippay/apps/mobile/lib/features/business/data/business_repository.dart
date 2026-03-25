import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../../../core/constants/api_constants.dart';

class BusinessRepository {
  final ApiService _api;
  BusinessRepository(this._api);

  Future<Map<String, dynamic>> registerBusiness(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConstants.registerBusiness, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyBusiness() async {
    final response = await _api.get(ApiConstants.myBusiness);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBusiness(
      String id, Map<String, dynamic> data) async {
    final response = await _api.patch(ApiConstants.businessById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDashboardStats(String id) async {
    final response = await _api.get(ApiConstants.businessDashboard(id));
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getStaffBreakdown(String id) async {
    final response = await _api.get(ApiConstants.businessStaff(id));
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getSatisfactionReport(String id) async {
    final response = await _api.get(ApiConstants.businessSatisfaction(id));
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getBulkQrCodes(String id) async {
    final response = await _api.get(ApiConstants.businessQrCodes(id));
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> inviteMember(
      String businessId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiConstants.inviteMember(businessId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeMember(
      String businessId, String memberId) async {
    final response =
        await _api.delete(ApiConstants.removeMember(businessId, memberId));
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyInvitations() async {
    final response = await _api.get(ApiConstants.myInvitations);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> respondToInvitation(
      String invitationId, String response) async {
    final res = await _api.post(
      ApiConstants.respondInvitation(invitationId),
      data: {'response': response},
    );
    return res.data as Map<String, dynamic>;
  }
}

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.read(apiServiceProvider));
});
