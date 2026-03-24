class QrCodeModel {
  final String id;
  final String providerId;
  final String type;
  final String? qrImageUrl;
  final String? upiUrl;
  final String? locationLabel;
  final int scanCount;
  final bool isActive;
  final DateTime createdAt;

  QrCodeModel({
    required this.id,
    required this.providerId,
    required this.type,
    this.qrImageUrl,
    this.upiUrl,
    this.locationLabel,
    required this.scanCount,
    required this.isActive,
    required this.createdAt,
  });

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      type: json['type'] as String,
      qrImageUrl: json['qrImageUrl'] as String?,
      upiUrl: json['upiUrl'] as String?,
      locationLabel: json['locationLabel'] as String?,
      scanCount: (json['scanCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'type': type,
      'qrImageUrl': qrImageUrl,
      'upiUrl': upiUrl,
      'locationLabel': locationLabel,
      'scanCount': scanCount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
