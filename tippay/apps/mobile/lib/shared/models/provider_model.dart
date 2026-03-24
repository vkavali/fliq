class ProviderModel {
  final String id;
  final String? displayName;
  final String category;
  final double? ratingAverage;
  final int totalTipsReceived;
  final String? qrCodeUrl;
  final String? upiVpa;
  final String? payoutPreference;

  ProviderModel({
    required this.id,
    this.displayName,
    required this.category,
    this.ratingAverage,
    required this.totalTipsReceived,
    this.qrCodeUrl,
    this.upiVpa,
    this.payoutPreference,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] as String? ?? json['providerId'] as String,
      displayName: json['displayName'] as String? ?? json['name'] as String?,
      category: json['category'] as String? ?? 'OTHER',
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
      totalTipsReceived: (json['totalTipsReceived'] as num?)?.toInt() ?? 0,
      qrCodeUrl: json['qrCodeUrl'] as String?,
      upiVpa: json['upiVpa'] as String?,
      payoutPreference: json['payoutPreference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'category': category,
      'ratingAverage': ratingAverage,
      'totalTipsReceived': totalTipsReceived,
      'qrCodeUrl': qrCodeUrl,
      'upiVpa': upiVpa,
      'payoutPreference': payoutPreference,
    };
  }

  ProviderModel copyWith({
    String? id,
    String? displayName,
    String? category,
    double? ratingAverage,
    int? totalTipsReceived,
    String? qrCodeUrl,
    String? upiVpa,
    String? payoutPreference,
  }) {
    return ProviderModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      totalTipsReceived: totalTipsReceived ?? this.totalTipsReceived,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      upiVpa: upiVpa ?? this.upiVpa,
      payoutPreference: payoutPreference ?? this.payoutPreference,
    );
  }
}

/// Lightweight model for public-facing provider info (used when scanning QR).
class ProviderPublicModel {
  final String id;
  final String name;
  final String category;

  ProviderPublicModel({
    required this.id,
    required this.name,
    required this.category,
  });

  factory ProviderPublicModel.fromJson(Map<String, dynamic> json) {
    return ProviderPublicModel(
      id: json['providerId'] as String? ?? json['id'] as String,
      name: json['providerName'] as String? ?? json['name'] as String? ?? 'Provider',
      category: json['category'] as String? ?? 'OTHER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }
}
