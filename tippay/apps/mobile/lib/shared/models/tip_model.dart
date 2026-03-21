class TipModel {
  final String id;
  final String? customerId;
  final String providerId;
  final int amountPaise;
  final int netAmountPaise;
  final String source;
  final String status;
  final String? message;
  final int? rating;
  final String? providerName;
  final String? customerName;
  final DateTime createdAt;

  TipModel({
    required this.id,
    this.customerId,
    required this.providerId,
    required this.amountPaise,
    required this.netAmountPaise,
    required this.source,
    required this.status,
    this.message,
    this.rating,
    this.providerName,
    this.customerName,
    required this.createdAt,
  });

  factory TipModel.fromJson(Map<String, dynamic> json) {
    return TipModel(
      id: json['id'] as String,
      customerId: json['customerId'] as String?,
      providerId: json['providerId'] as String,
      amountPaise: json['amountPaise'] as int,
      netAmountPaise: json['netAmountPaise'] as int,
      source: json['source'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      rating: json['rating'] as int?,
      providerName: json['provider']?['name'] as String?,
      customerName: json['customer']?['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String get amountRupees => (amountPaise / 100).toStringAsFixed(0);
}
