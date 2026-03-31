import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/pending_tip_model.dart';

String _generateId() {
  final rand = Random();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final suffix = List.generate(6, (_) => rand.nextInt(36).toRadixString(36)).join();
  return '${ts}_$suffix';
}

const _kQueueKey = 'offline_tip_queue';

// ── Providers ──────────────────────────────────────────────────────────────

final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return OfflineQueueService();
});

/// Stream of pending tip count — used to show badge
final pendingTipCountProvider = StreamProvider<int>((ref) {
  return ref.watch(offlineQueueServiceProvider).pendingCountStream;
});

/// True when the device is currently offline
final isOfflineProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((result) => result == ConnectivityResult.none);
});

// ── Service ────────────────────────────────────────────────────────────────

class OfflineQueueService {
  final _controller = StreamController<int>.broadcast();
  StreamSubscription? _connectivitySub;
  bool _isProcessing = false;

  Stream<int> get pendingCountStream => _controller.stream;

  /// Start monitoring connectivity changes and auto-process queue when online.
  void startMonitoring(Function(PendingTipModel) onProcess) {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline) {
        _processQueue(onProcess);
      }
    });
  }

  void stopMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Enqueue a tip for later processing.
  Future<void> enqueueTip(PendingTipModel tip) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue(prefs);
    queue.add(tip);
    await _saveQueue(prefs, queue);
    _controller.add(queue.length);
  }

  /// Return all pending tips.
  Future<List<PendingTipModel>> getPendingTips() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadQueue(prefs);
  }

  /// Remove a tip from the queue by ID.
  Future<void> removeTip(String tipId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue(prefs);
    queue.removeWhere((t) => t.id == tipId);
    await _saveQueue(prefs, queue);
    _controller.add(queue.length);
  }

  /// Clear the entire queue.
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueueKey);
    _controller.add(0);
  }

  /// Check current queue length.
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue(prefs);
    return queue.length;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _processQueue(Function(PendingTipModel) onProcess) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await _loadQueue(prefs);

      for (final tip in List<PendingTipModel>.from(queue)) {
        try {
          await onProcess(tip);
          await removeTip(tip.id);
        } catch (_) {
          // Keep failed tips in queue for retry
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<PendingTipModel>> _loadQueue(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_kQueueKey) ?? [];
    return raw
        .map((s) {
          try {
            return PendingTipModel.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<PendingTipModel>()
        .toList();
  }

  Future<void> _saveQueue(SharedPreferences prefs, List<PendingTipModel> queue) async {
    await prefs.setStringList(_kQueueKey, queue.map((t) => t.toJsonString()).toList());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _controller.close();
  }
}
