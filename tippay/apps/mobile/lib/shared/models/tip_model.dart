class TipModel {
  final String id;
  final String? customerId;
  final String providerId;
  final int amountPaise;
  final int commissionPaise;
  final int netAmountPaise;
  final int? gstOnCommissionPaise;
  final String? paymentMethod;
  final String source;
  final String status; // INITIATED, PAID, SETTLED, FAILED, REFUNDED
  final String? message;
  final int? rating;
  final String? customerName;
  final String? providerName;
  final DateTime createdAt;

  TipModel({
    required this.id,
    this.customerId,
    required this.providerId,
    required this.amountPaise,
    required this.commissionPaise,
    required this.netAmountPaise,
    this.gstOnCommissionPaise,
    this.paymentMethod,
    required this.source,
    required this.status,
    this.message,
    this.rating,
    this.customerName,
    this.providerName,
    required this.createdAt,
  });

  factory TipModel.fromJson(Map<String, dynamic> json) {
    return TipModel(
      id: json['id'] as String,
      customerId: json['customerId'] as String?,
      providerId: json['providerId'] as String,
      amountPaise: (json['amountPaise'] as num).toInt(),
      commissionPaise: (json['commissionPaise'] as num?)?.toInt() ?? 0,
      netAmountPaise: (json['netAmountPaise'] as num).toInt(),
      gstOnCommissionPaise: (json['gstOnCommissionPaise'] as num?)?.toInt(),
      paymentMethod: json['paymentMethod'] as String?,
      source: json['source'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      customerName: json['customerName'] as String? ??
          (json['customer'] as Map<String, dynamic>?)?['name'] as String?,
      providerName: json['providerName'] as String? ??
          (json['provider'] as Map<String, dynamic>?)?['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'providerId': providerId,
      'amountPaise': amountPaise,
      'commissionPaise': commissionPaise,
      'netAmountPaise': netAmountPaise,
      'gstOnCommissionPaise': gstOnCommissionPaise,
      'paymentMethod': paymentMethod,
      'source': source,
      'status': status,
      'message': message,
      'rating': rating,
      'customerName': customerName,
      'providerName': providerName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get amountRupees => (amountPaise / 100).toStringAsFixed(0);
  String get netAmountRupees => (netAmountPaise / 100).toStringAsFixed(0);
  String get commissionRupees => (commissionPaise / 100).toStringAsFixed(2);

  bool get isPaid => status == 'PAID' || status == 'SETTLED';
  bool get isFailed => status == 'FAILED';
  bool get isRefunded => status == 'REFUNDED';
}
