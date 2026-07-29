import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nirs_quota.dart';
import '../models/premium_access.dart';
import '../models/app_user.dart';
import '../config/subscription_limits.dart';

class NirsLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<NirsQuotaStatus> getQuotaStatus({
    required String userId,
    required PremiumAccess access,
  }) async {
    if (access.grantsFullPremium) {
      final now = DateTime.now();
      return NirsQuotaStatus.allowed(
        used: 0,
        limit: 9999,
        resetsAt: DateTime(now.year, now.month + 1, 1),
      );
    }

    if (!access.canUseNirsMonitoring) {
      final previewLimit = access.role == UserRole.hobbyFarmer
          ? SubscriptionLimits.hobbyPremiumNirsMonthlyLoads
          : SubscriptionLimits.proPremiumNirsMonthlyLoads;
      return NirsQuotaStatus.blocked(
        used: 0,
        limit: previewLimit,
        blockReasonKey: 'land_nirs_subscription_required',
      );
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final counters = _normalizeCounters(data);
    final now = DateTime.now();
    final limit = access.monthlyNirsLimit;
    final monthly = _applyMonthlyReset(counters, now);

    if (monthly.loadsThisMonth >= limit) {
      return NirsQuotaStatus.blocked(
        used: monthly.loadsThisMonth,
        limit: limit,
        blockReasonKey: 'land_nirs_limit_monthly',
        resetsAt: DateTime(now.year, now.month + 1, 1),
      );
    }

    return NirsQuotaStatus.allowed(
      used: monthly.loadsThisMonth,
      limit: limit,
      resetsAt: DateTime(now.year, now.month + 1, 1),
    );
  }

  Future<void> recordNirsLoad({required String userId}) async {
    final userRef = _firestore.collection('users').doc(userId);
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? {};
      var counters = _applyMonthlyReset(_normalizeCounters(data), now);

      transaction.set(
        userRef,
        {
          'nirsLoadsThisMonth': counters.loadsThisMonth + 1,
          'lastNirsReset': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
    });
  }

  _NirsCounters _normalizeCounters(Map<String, dynamic> data) {
    return _NirsCounters(
      loadsThisMonth: _asInt(data['nirsLoadsThisMonth']),
      lastReset: _asDateTime(data['lastNirsReset']),
    );
  }

  _NirsCounters _applyMonthlyReset(_NirsCounters counters, DateTime now) {
    if (!_isSameMonth(counters.lastReset, now)) {
      return _NirsCounters(loadsThisMonth: 0, lastReset: now);
    }
    return counters;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isSameMonth(DateTime? a, DateTime now) {
    if (a == null) return false;
    return a.year == now.year && a.month == now.month;
  }
}

class _NirsCounters {
  final int loadsThisMonth;
  final DateTime? lastReset;

  const _NirsCounters({
    required this.loadsThisMonth,
    this.lastReset,
  });
}

final nirsLimitServiceProvider = Provider<NirsLimitService>(
  (ref) => NirsLimitService(),
);
