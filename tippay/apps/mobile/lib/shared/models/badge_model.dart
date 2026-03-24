class BadgeModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final String? iconUrl;
  final String category;
  final int threshold;
  final bool earned;
  final DateTime? earnedAt;

  BadgeModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.category,
    required this.threshold,
    required this.earned,
    this.earnedAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      iconUrl: json['iconUrl'] as String?,
      category: json['category'] as String,
      threshold: (json['threshold'] as num).toInt(),
      earned: json['earned'] as bool? ?? false,
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'category': category,
      'threshold': threshold,
      'earned': earned,
      'earnedAt': earnedAt?.toIso8601String(),
    };
  }

  /// Return an icon string based on badge code for display.
  String get emoji {
    return switch (code) {
      'first_tip' => '\u{1F389}',
      'tip_10' => '\u{1F49B}',
      'tip_50' => '\u{1F3C5}',
      'tip_100' => '\u{1F3C6}',
      'big_tipper' => '\u{1F4B0}',
      'mega_tipper' => '\u{1F48E}',
      'streak_3' => '\u{1F525}',
      'streak_7' => '\u{2694}\u{FE0F}',
      'streak_30' => '\u{1F451}',
      'first_earned' => '\u{2B50}',
      'tips_50' => '\u{1F31F}',
      'top_rated' => '\u{1F947}',
      'earned_10k' => '\u{1F4B8}',
      _ => '\u{1F3C5}',
    };
  }
}
