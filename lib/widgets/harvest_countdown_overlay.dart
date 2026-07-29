import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/harvest_formatter.dart';

class HarvestCountdownOverlay extends StatefulWidget {
  const HarvestCountdownOverlay({
    super.key,
    required this.harvestDateTime,
    required this.child,
    this.showBadge = true,
    this.isDelivery = false,
    this.upcomingMode,
  });

  final DateTime harvestDateTime;
  final Widget child;
  final bool showBadge;
  final bool isDelivery;
  final String? upcomingMode;

  @override
  State<HarvestCountdownOverlay> createState() =>
      _HarvestCountdownOverlayState();
}

class _HarvestCountdownOverlayState extends State<HarvestCountdownOverlay> {
  Timer? _timer;
  late String _countdownText;

  @override
  void initState() {
    super.initState();
    _refreshCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_refreshCountdown);
    });
  }

  void _refreshCountdown() {
    _countdownText = HarvestFormatter.fullCountdownLine(
      widget.harvestDateTime,
      isDelivery: widget.isDelivery,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        if (widget.showBadge)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                HarvestFormatter.upcomingBadge(upcomingMode: widget.upcomingMode),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Text(
              _countdownText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
