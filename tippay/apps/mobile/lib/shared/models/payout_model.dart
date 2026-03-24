class PayoutModel {
  final String id;
  final int amountPaise;
  final String mode; // UPI, IMPS, NEFT
  final String status; // PENDING_BATCH, INITIATED, PROCESSED, SETTLED, FAILED
  final String? failureReason;
  final String? utr;
  final DateTime createdAt;
  final DateTime? settledAt;

  PayoutModel({
    required this.id,
    required this.amountPaise,
    required this.mode,
    required this.status,
    this.failureReason,
    this.utr,
    required this.createdAt,
    this.settledAt,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    return PayoutModel(
      id: json['id'] as String,
      amountPaise: (json['amountPaise'] as num).toInt(),
      mode: json['mode'] as String,
      status: json['status'] as String,
      failureReason: json['failureReason'] as String?,
      utr: json['utr'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settledAt: json['settledAt'] != null
          ? DateTime.parse(json['settledAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amountPaise': amountPaise,
      'mode': mode,
      'status': status,
      'failureReason': failureReason,
      'utr': utr,
      'createdAt': createdAt.toIso8601String(),
      'settledAt': settledAt?.toIso8601String(),
    };
  }

  String get amountRupees => (amountPaise / 100).toStringAsFixed(2);

  bool get isSettled => status == 'SETTLED';
  bool get isFailed => status == 'FAILED';
  bool get isPending =>
      status == 'PENDING_BATCH' || status == 'INITIATED' || status == 'PROCESSED';
}
