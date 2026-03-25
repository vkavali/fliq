import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

final recurringTipsRepositoryProvider = Provider<RecurringTipsRepository>((ref) {
  return RecurringTipsRepository(ref.read(dioProvider));
});

enum RecurringTipFrequency { weekly, monthly }

enum RecurringTipStatus {
  pendingAuthorization,
  active,
  paused,
  cancelled,
  halted,
  completed,
}

class RecurringTip {
  final String id;
  final String customerId;
  final String providerId;
  final String? providerName;
  final String? providerCategory;
  final int amountPaise;
  final RecurringTipFrequency frequency;
  final RecurringTipStatus status;
  final DateTime? nextChargeDate;
  final int totalCharges;
  final DateTime createdAt;

  const RecurringTip({
    required this.id,
    required this.customerId,
    required this.providerId,
    this.providerName,
    this.providerCategory,
    required this.amountPaise,
    required this.frequency,
    required this.status,
    this.nextChargeDate,
    required this.totalCharges,
    required this.createdAt,
  });

  factory RecurringTip.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>?;
    final providerProfile = provider?['providerProfile'] as Map<String, dynamic>?;
    return RecurringTip(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      providerId: json['providerId'] as String,
      providerName: provider?['name'] as String?,
      providerCategory: providerProfile?['category'] as String?,
      amountPaise: json['amountPaise'] is int
          ? json['amountPaise'] as int
          : int.tryParse(json['amountPaise'].toString()) ?? 0,
      frequency: _parseFrequency(json['frequency'] as String),
      status: _parseStatus(json['status'] as String),
      nextChargeDate: json['nextChargeDate'] != null
          ? DateTime.tryParse(json['nextChargeDate'] as String)
          : null,
      totalCharges: json['totalCharges'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static RecurringTipFrequency _parseFrequency(String s) {
    switch (s.toUpperCase()) {
      case 'WEEKLY':
        return RecurringTipFrequency.weekly;
      default:
        return RecurringTipFrequency.monthly;
    }
  }

  static RecurringTipStatus _parseStatus(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING_AUTHORIZATION':
        return RecurringTipStatus.pendingAuthorization;
      case 'ACTIVE':
        return RecurringTipStatus.active;
      case 'PAUSED':
        return RecurringTipStatus.paused;
      case 'CANCELLED':
        return RecurringTipStatus.cancelled;
      case 'HALTED':
        return RecurringTipStatus.halted;
      case 'COMPLETED':
        return RecurringTipStatus.completed;
      default:
        return RecurringTipStatus.pendingAuthorization;
    }
  }

  String get frequencyLabel =>
      frequency == RecurringTipFrequency.weekly ? 'Weekly' : 'Monthly';

  String get statusLabel {
    switch (status) {
      case RecurringTipStatus.pendingAuthorization:
        return 'Pending Authorization';
      case RecurringTipStatus.active:
        return 'Active';
      case RecurringTipStatus.paused:
        return 'Paused';
      case RecurringTipStatus.cancelled:
        return 'Cancelled';
      case RecurringTipStatus.halted:
        return 'Halted';
      case RecurringTipStatus.completed:
        return 'Completed';
    }
  }

  bool get isManageable =>
      status == RecurringTipStatus.active || status == RecurringTipStatus.paused;
}

class CreateRecurringTipResponse {
  final String recurringTipId;
  final String subscriptionId;
  final String authorizationUrl;
  final String razorpayKeyId;
  final String providerName;

  const CreateRecurringTipResponse({
    required this.recurringTipId,
    required this.subscriptionId,
    required this.authorizationUrl,
    required this.razorpayKeyId,
    required this.providerName,
  });

  factory CreateRecurringTipResponse.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>? ?? {};
    return CreateRecurringTipResponse(
      recurringTipId: json['recurringTipId'] as String,
      subscriptionId: json['subscriptionId'] as String,
      authorizationUrl: json['authorizationUrl'] as String,
      razorpayKeyId: json['razorpayKeyId'] as String,
      providerName: provider['name'] as String? ?? '',
    );
  }
}

class RecurringTipsRepository {
  final Dio _dio;

  RecurringTipsRepository(this._dio);

  Future<CreateRecurringTipResponse> createRecurringTip({
    required String providerId,
    required int amountPaise,
    required RecurringTipFrequency frequency,
  }) async {
    final response = await _dio.post(ApiConstants.recurringTips, data: {
      'providerId': providerId,
      'amountPaise': amountPaise,
      'frequency': frequency == RecurringTipFrequency.weekly ? 'WEEKLY' : 'MONTHLY',
    });
    return CreateRecurringTipResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<List<RecurringTip>> getMyRecurringTips() async {
    final response = await _dio.get(ApiConstants.myRecurringTips);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => RecurringTip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecurringTip>> getProviderRecurringTips() async {
    final response = await _dio.get(ApiConstants.providerRecurringTips);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => RecurringTip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pauseRecurringTip(String id) async {
    await _dio.patch(ApiConstants.pauseRecurringTip(id));
  }

  Future<void> resumeRecurringTip(String id) async {
    await _dio.patch(ApiConstants.resumeRecurringTip(id));
  }

  Future<void> cancelRecurringTip(String id) async {
    await _dio.delete(ApiConstants.cancelRecurringTip(id));
  }
}
