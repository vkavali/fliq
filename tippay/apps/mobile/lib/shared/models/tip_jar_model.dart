class TipJarMemberModel {
  final String id;
  final String providerId;
  final String? providerName;
  final String? roleLabel;
  final double splitPercentage;
  final bool isActive;

  const TipJarMemberModel({
    required this.id,
    required this.providerId,
    this.providerName,
    this.roleLabel,
    required this.splitPercentage,
    required this.isActive,
  });

  factory TipJarMemberModel.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>?;
    return TipJarMemberModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      providerName: provider?['name'] as String?,
      roleLabel: json['roleLabel'] as String?,
      splitPercentage: (json['splitPercentage'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class TipJarModel {
  final String id;
  final String name;
  final String? description;
  final String eventType;
  final String shortCode;
  final bool isActive;
  final DateTime? expiresAt;
  final int totalCollectedPaise;
  final int? targetAmountPaise;
  final List<TipJarMemberModel> members;
  final int contributionCount;
  final String? shareableUrl;
  final String createdById;
  final String? createdByName;

  const TipJarModel({
    required this.id,
    required this.name,
    this.description,
    required this.eventType,
    required this.shortCode,
    required this.isActive,
    this.expiresAt,
    required this.totalCollectedPaise,
    this.targetAmountPaise,
    required this.members,
    required this.contributionCount,
    this.shareableUrl,
    required this.createdById,
    this.createdByName,
  });

  factory TipJarModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    return TipJarModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      eventType: json['eventType'] as String? ?? 'CUSTOM',
      shortCode: json['shortCode'] as String,
      isActive: json['isActive'] as bool? ?? true,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null,
      totalCollectedPaise: (json['totalCollected'] as num?)?.toInt() ?? 0,
      targetAmountPaise: (json['targetAmount'] as num?)?.toInt(),
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => TipJarMemberModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      contributionCount: (count?['contributions'] as num?)?.toInt() ?? 0,
      shareableUrl: json['shareableUrl'] as String?,
      createdById: json['createdById'] as String,
      createdByName: createdBy?['name'] as String?,
    );
  }

  String get eventTypeLabel => switch (eventType) {
        'WEDDING' => 'Wedding',
        'RESTAURANT' => 'Restaurant',
        'SALON' => 'Salon',
        'EVENT' => 'Event',
        _ => 'Custom',
      };
}
