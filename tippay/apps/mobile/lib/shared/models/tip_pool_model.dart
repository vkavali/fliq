class TipPoolModel {
  final String id;
  final String name;
  final String ownerId;
  final String? ownerName;
  final String? description;
  final String splitMethod; // EQUAL, PERCENTAGE, ROLE_BASED
  final bool isActive;
  final List<TipPoolMemberModel> members;
  final int tipCount;
  final DateTime createdAt;

  TipPoolModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.ownerName,
    this.description,
    required this.splitMethod,
    required this.isActive,
    this.members = const [],
    this.tipCount = 0,
    required this.createdAt,
  });

  factory TipPoolModel.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List?)
            ?.map((e) =>
                TipPoolMemberModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final owner = json['owner'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;

    return TipPoolModel(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      ownerName: owner?['name'] as String?,
      description: json['description'] as String?,
      splitMethod: json['splitMethod'] as String? ?? 'EQUAL',
      isActive: json['isActive'] as bool? ?? true,
      members: membersList,
      tipCount: count?['tips'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  int get memberCount => members.length;

  bool isOwner(String userId) => ownerId == userId;

  String get splitMethodLabel {
    switch (splitMethod) {
      case 'EQUAL':
        return 'Equal Split';
      case 'PERCENTAGE':
        return 'Percentage';
      case 'ROLE_BASED':
        return 'Role Based';
      default:
        return splitMethod;
    }
  }
}

class TipPoolMemberModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userPhone;
  final String? role;
  final double? splitPercentage;
  final bool isActive;
  final DateTime joinedAt;

  TipPoolMemberModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userPhone,
    this.role,
    this.splitPercentage,
    required this.isActive,
    required this.joinedAt,
  });

  factory TipPoolMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return TipPoolMemberModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: user?['name'] as String?,
      userPhone: user?['phone'] as String?,
      role: json['role'] as String?,
      splitPercentage: (json['splitPercentage'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}

class TipPoolEarnings {
  final String poolId;
  final String poolName;
  final String splitMethod;
  final int totalEarningsPaise;
  final int tipCount;
  final List<MemberEarning> members;

  TipPoolEarnings({
    required this.poolId,
    required this.poolName,
    required this.splitMethod,
    required this.totalEarningsPaise,
    required this.tipCount,
    required this.members,
  });

  factory TipPoolEarnings.fromJson(Map<String, dynamic> json) {
    return TipPoolEarnings(
      poolId: json['poolId'] as String,
      poolName: json['poolName'] as String,
      splitMethod: json['splitMethod'] as String,
      totalEarningsPaise: (json['totalEarningsPaise'] as num).toInt(),
      tipCount: (json['tipCount'] as num).toInt(),
      members: ((json['members'] as List?) ?? [])
          .map((e) => MemberEarning.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get totalEarningsRupees =>
      (totalEarningsPaise / 100).toStringAsFixed(0);
}

class MemberEarning {
  final String memberId;
  final String userId;
  final String? userName;
  final String? userPhone;
  final String? role;
  final double splitPercentage;
  final int amountPaise;

  MemberEarning({
    required this.memberId,
    required this.userId,
    this.userName,
    this.userPhone,
    this.role,
    required this.splitPercentage,
    required this.amountPaise,
  });

  factory MemberEarning.fromJson(Map<String, dynamic> json) {
    return MemberEarning(
      memberId: json['memberId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      userPhone: json['userPhone'] as String?,
      role: json['role'] as String?,
      splitPercentage: (json['splitPercentage'] as num).toDouble(),
      amountPaise: (json['amountPaise'] as num).toInt(),
    );
  }

  String get amountRupees => (amountPaise / 100).toStringAsFixed(0);
}
