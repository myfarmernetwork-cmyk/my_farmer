class NirsQuotaStatus {
  final bool canLoad;
  final int used;
  final int limit;
  final int remaining;
  final String? blockReasonKey;
  final DateTime? resetsAt;

  const NirsQuotaStatus({
    required this.canLoad,
    required this.used,
    required this.limit,
    required this.remaining,
    this.blockReasonKey,
    this.resetsAt,
  });

  factory NirsQuotaStatus.blocked({
    required int used,
    required int limit,
    required String blockReasonKey,
    DateTime? resetsAt,
  }) {
    return NirsQuotaStatus(
      canLoad: false,
      used: used,
      limit: limit,
      remaining: 0,
      blockReasonKey: blockReasonKey,
      resetsAt: resetsAt,
    );
  }

  factory NirsQuotaStatus.allowed({
    required int used,
    required int limit,
    DateTime? resetsAt,
  }) {
    return NirsQuotaStatus(
      canLoad: true,
      used: used,
      limit: limit,
      remaining: limit - used,
      resetsAt: resetsAt,
    );
  }
}
