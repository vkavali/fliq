class StreakModel {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastTipDate;

  StreakModel({
    required this.currentStreak,
    required this.longestStreak,
    this.lastTipDate,
  });

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastTipDate: json['lastTipDate'] != null
          ? DateTime.parse(json['lastTipDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastTipDate': lastTipDate?.toIso8601String(),
    };
  }

  bool get isActive => currentStreak > 0;

  /// Whether the streak is at risk (last tip was yesterday, must tip today).
  bool get isAtRisk {
    if (lastTipDate == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      lastTipDate!.year,
      lastTipDate!.month,
      lastTipDate!.day,
    );
    return todayStart.difference(lastDay).inDays == 1;
  }

  /// Whether the user has already tipped today.
  bool get tippedToday {
    if (lastTipDate == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      lastTipDate!.year,
      lastTipDate!.month,
      lastTipDate!.day,
    );
    return lastDay == todayStart;
  }
}
