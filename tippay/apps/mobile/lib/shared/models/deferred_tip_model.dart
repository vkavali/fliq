class DeferredTipModel {
  final String id;
  final String customerId;
  final String providerId;
  final String? providerName;
  final String? providerCategory;
  final int amountPaise;
  final String? message;
  final int? rating;
  final DateTime promisedAt;
  final DateTime dueAt;
  final String status; // PROMISED, COLLECTED, EXPIRED, CANCELLED
  final String? tipId;

  const DeferredTipModel({
    required this.id,
    required this.customerId,
    required this.providerId,
    this.providerName,
    this.providerCategory,
    required this.amountPaise,
    this.message,
    this.rating,
    required this.promisedAt,
    required this.dueAt,
    required this.status,
    this.tipId,
  });

  factory DeferredTipModel.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>?;
    final providerProfile = provider?['providerProfile'] as Map<String, dynamic>?;
    return DeferredTipModel(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      providerId: json['providerId'] as String,
      providerName: provider?['name'] as String?,
      providerCategory: providerProfile?['category'] as String?,
      amountPaise: (json['amountPaise'] as num).toInt(),
      message: json['message'] as String?,
      rating: json['rating'] as int?,
      promisedAt: DateTime.parse(json['promisedAt'] as String),
      dueAt: DateTime.parse(json['dueAt'] as String),
      status: json['status'] as String,
      tipId: json['tipId'] as String?,
    );
  }

  bool get isExpired => status == 'EXPIRED' || (status == 'PROMISED' && DateTime.now().isAfter(dueAt));
  bool get isPending => status == 'PROMISED' && !isExpired;
  bool get isCollected => status == 'COLLECTED';

  Duration get timeRemaining => dueAt.difference(DateTime.now());

  String get timeRemainingLabel {
    if (isExpired) return 'Expired';
    if (isCollected) return 'Paid ✓';
    final remaining = timeRemaining;
    if (remaining.inHours > 0) return '${remaining.inHours}h remaining';
    if (remaining.inMinutes > 0) return '${remaining.inMinutes}m remaining';
    return 'Expiring soon';
  }
}
