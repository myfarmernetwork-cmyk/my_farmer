enum ScanLimitTier {
  intro,
  monthly,
  subscription,
}

class ScanQuotaStatus {
  final bool canScan;
  final int used;
  final int limit;
  final int remaining;
  final ScanLimitTier tier;
  final String? blockReasonKey;
  final DateTime? resetsAt;
  /// Kupljeni skenovi (ne resetiraju se mjesečno).
  final int bonusRemaining;

  const ScanQuotaStatus({
    required this.canScan,
    required this.used,
    required this.limit,
    required this.remaining,
    required this.tier,
    this.blockReasonKey,
    this.resetsAt,
    this.bonusRemaining = 0,
  });

  factory ScanQuotaStatus.blocked({
    required ScanLimitTier tier,
    required int used,
    required int limit,
    required String blockReasonKey,
    DateTime? resetsAt,
  }) {
    return ScanQuotaStatus(
      canScan: false,
      used: used,
      limit: limit,
      remaining: 0,
      tier: tier,
      blockReasonKey: blockReasonKey,
      resetsAt: resetsAt,
      bonusRemaining: 0,
    );
  }

  factory ScanQuotaStatus.allowed({
    required ScanLimitTier tier,
    required int used,
    required int limit,
    DateTime? resetsAt,
    int bonusRemaining = 0,
  }) {
    final monthlyRemaining = (limit - used).clamp(0, limit);
    return ScanQuotaStatus(
      canScan: true,
      used: used,
      limit: limit,
      remaining: monthlyRemaining + bonusRemaining,
      tier: tier,
      resetsAt: resetsAt,
      bonusRemaining: bonusRemaining,
    );
  }
}
