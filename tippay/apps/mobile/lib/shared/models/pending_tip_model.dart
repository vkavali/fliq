import 'dart:convert';

class PendingTipModel {
  final String id;
  final String providerId;
  final String providerName;
  final String category;
  final int amountPaise;
  final String? message;
  final int? rating;
  final String source;
  final DateTime queuedAt;
  final String? providerUpiVpa;

  const PendingTipModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.category,
    required this.amountPaise,
    this.message,
    this.rating,
    required this.source,
    required this.queuedAt,
    this.providerUpiVpa,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'providerName': providerName,
        'category': category,
        'amountPaise': amountPaise,
        'message': message,
        'rating': rating,
        'source': source,
        'queuedAt': queuedAt.toIso8601String(),
        'providerUpiVpa': providerUpiVpa,
      };

  factory PendingTipModel.fromJson(Map<String, dynamic> json) {
    return PendingTipModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      category: json['category'] as String,
      amountPaise: json['amountPaise'] as int,
      message: json['message'] as String?,
      rating: json['rating'] as int?,
      source: json['source'] as String,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      providerUpiVpa: json['providerUpiVpa'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static PendingTipModel fromJsonString(String s) =>
      PendingTipModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
