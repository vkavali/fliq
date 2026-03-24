class PaymentLinkModel {
  final String id;
  final String shortCode;
  final String? description;
  final int? suggestedAmountPaise;
  final bool allowCustomAmount;
  final int clickCount;
  final String shareableUrl;
  final DateTime createdAt;

  PaymentLinkModel({
    required this.id,
    required this.shortCode,
    this.description,
    this.suggestedAmountPaise,
    required this.allowCustomAmount,
    required this.clickCount,
    required this.shareableUrl,
    required this.createdAt,
  });

  factory PaymentLinkModel.fromJson(Map<String, dynamic> json) {
    return PaymentLinkModel(
      id: json['id'] as String,
      shortCode: json['shortCode'] as String,
      description: json['description'] as String?,
      suggestedAmountPaise: (json['suggestedAmountPaise'] as num?)?.toInt(),
      allowCustomAmount: json['allowCustomAmount'] as bool? ?? true,
      clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
      shareableUrl: json['shareableUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shortCode': shortCode,
      'description': description,
      'suggestedAmountPaise': suggestedAmountPaise,
      'allowCustomAmount': allowCustomAmount,
      'clickCount': clickCount,
      'shareableUrl': shareableUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get suggestedAmountRupees =>
      suggestedAmountPaise != null ? (suggestedAmountPaise! / 100).toStringAsFixed(0) : '-';
}
