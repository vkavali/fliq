import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/recurring_tips_repository.dart';

// ── State ────────────────────────────────────────────────────────────────────

class RecurringTipsState {
  final List<RecurringTip> tips;
  final bool isLoading;
  final String? error;

  const RecurringTipsState({
    this.tips = const [],
    this.isLoading = false,
    this.error,
  });

  RecurringTipsState copyWith({
    List<RecurringTip>? tips,
    bool? isLoading,
    String? error,
  }) {
    return RecurringTipsState(
      tips: tips ?? this.tips,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class RecurringTipsNotifier extends StateNotifier<RecurringTipsState> {
  final RecurringTipsRepository _repo;

  RecurringTipsNotifier(this._repo) : super(const RecurringTipsState());

  Future<void> loadMyTips() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tips = await _repo.getMyRecurringTips();
      state = state.copyWith(tips: tips, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> pause(String id) async {
    try {
      await _repo.pauseRecurringTip(id);
      state = state.copyWith(
        tips: state.tips.map((t) {
          if (t.id == id) {
            return RecurringTip(
              id: t.id,
              customerId: t.customerId,
              providerId: t.providerId,
              providerName: t.providerName,
              providerCategory: t.providerCategory,
              amountPaise: t.amountPaise,
              frequency: t.frequency,
              status: RecurringTipStatus.paused,
              nextChargeDate: t.nextChargeDate,
              totalCharges: t.totalCharges,
              createdAt: t.createdAt,
            );
          }
          return t;
        }).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resume(String id) async {
    try {
      await _repo.resumeRecurringTip(id);
      state = state.copyWith(
        tips: state.tips.map((t) {
          if (t.id == id) {
            return RecurringTip(
              id: t.id,
              customerId: t.customerId,
              providerId: t.providerId,
              providerName: t.providerName,
              providerCategory: t.providerCategory,
              amountPaise: t.amountPaise,
              frequency: t.frequency,
              status: RecurringTipStatus.active,
              nextChargeDate: t.nextChargeDate,
              totalCharges: t.totalCharges,
              createdAt: t.createdAt,
            );
          }
          return t;
        }).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      await _repo.cancelRecurringTip(id);
      state = state.copyWith(
        tips: state.tips.map((t) {
          if (t.id == id) {
            return RecurringTip(
              id: t.id,
              customerId: t.customerId,
              providerId: t.providerId,
              providerName: t.providerName,
              providerCategory: t.providerCategory,
              amountPaise: t.amountPaise,
              frequency: t.frequency,
              status: RecurringTipStatus.cancelled,
              nextChargeDate: t.nextChargeDate,
              totalCharges: t.totalCharges,
              createdAt: t.createdAt,
            );
          }
          return t;
        }).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final recurringTipsProvider =
    StateNotifierProvider<RecurringTipsNotifier, RecurringTipsState>((ref) {
  return RecurringTipsNotifier(ref.read(recurringTipsRepositoryProvider));
});
