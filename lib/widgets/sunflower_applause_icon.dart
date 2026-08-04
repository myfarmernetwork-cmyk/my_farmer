import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sunčogled — reakcija „Lijepo“ u Ljepotama sela.
/// Samo glava cvijeta, bez stabljike — čitljivo i u malom prikazu.
class SunflowerApplauseIcon extends StatelessWidget {
  const SunflowerApplauseIcon({
    super.key,
    required this.active,
    this.size = 28,
  });

  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SunflowerHeadPainter(active: active),
      ),
    );
  }
}

class _SunflowerHeadPainter extends CustomPainter {
  _SunflowerHeadPainter({required this.active});

  final bool active;

  static const _petalYellow = Color(0xFFFFD54F);
  static const _petalGold = Color(0xFFFFB300);
  static const _petalOrange = Color(0xFFFF8F00);
  static const _petalInactive = Color(0xFFFFE082);
  static const _hubDark = Color(0xFF4E342E);
  static const _hubMid = Color(0xFF6D4C41);
  static const _hubLight = Color(0xFF8D6E63);
  static const _seedDot = Color(0xFF3E2723);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final scale = w / 28;

    if (active) {
      _drawGlowRing(canvas, center, w * 0.46, scale);
    }

    _drawPetals(
      canvas: canvas,
      center: center,
      count: 14,
      length: w * 0.22,
      width: w * 0.11,
      radius: w * 0.17,
      fill: active ? _petalYellow : _petalInactive,
      stroke: active ? _petalGold : const Color(0xFFFFCA28),
      strokeWidth: scale * 0.7,
      showVeins: true,
    );

    _drawPetals(
      canvas: canvas,
      center: center,
      count: 10,
      length: w * 0.15,
      width: w * 0.085,
      radius: w * 0.11,
      fill: active ? _petalGold : const Color(0xFFFFECB3),
      stroke: active ? _petalOrange : const Color(0xFFFFD54F),
      strokeWidth: scale * 0.55,
      showVeins: false,
      angleOffset: math.pi / 10,
    );

    _drawHub(canvas, center, w * 0.155, scale, active);
  }

  void _drawGlowRing(Canvas canvas, Offset center, double radius, double scale) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE082).withValues(alpha: 0.55),
          const Color(0xFFFFB300).withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.55, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, glow);

    final ring = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 1.1;
    canvas.drawCircle(center, radius * 0.88, ring);
  }

  void _drawPetals({
    required Canvas canvas,
    required Offset center,
    required int count,
    required double length,
    required double width,
    required double radius,
    required Color fill,
    required Color stroke,
    required double strokeWidth,
    required bool showVeins,
    double angleOffset = 0,
  }) {
    final fillPaint = Paint()..color = fill;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 / count) * i - math.pi / 2 + angleOffset;
      final petalCenter = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + math.pi / 2);

      final petalPath = Path()
        ..moveTo(0, -length * 0.55)
        ..quadraticBezierTo(width * 0.55, -length * 0.15, width * 0.42, length * 0.42)
        ..quadraticBezierTo(0, length * 0.52, -width * 0.42, length * 0.42)
        ..quadraticBezierTo(-width * 0.55, -length * 0.15, 0, -length * 0.55)
        ..close();

      canvas.drawPath(petalPath, fillPaint);
      canvas.drawPath(petalPath, strokePaint);

      if (showVeins) {
        final vein = Paint()
          ..color = stroke.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.55
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(0, -length * 0.35),
          Offset(0, length * 0.28),
          vein,
        );
      }

      canvas.restore();
    }
  }

  void _drawHub(Canvas canvas, Offset center, double radius, double scale, bool active) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = active ? _hubMid : _hubLight,
    );

    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..color = active ? _hubDark : _hubMid
        ..style = PaintingStyle.fill,
    );

    final ring = Paint()
      ..color = _hubDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.6;
    canvas.drawCircle(center, radius * 0.88, ring);

    final dotPaint = Paint()..color = _seedDot.withValues(alpha: active ? 0.9 : 0.55);
    final dotRadius = scale * 0.75;
    final rings = active ? 3 : 2;

    for (var ringIndex = 0; ringIndex < rings; ringIndex++) {
      final ringRadius = radius * (0.22 + ringIndex * 0.22);
      final dots = 5 + ringIndex * 3;
      for (var i = 0; i < dots; i++) {
        final angle = (math.pi * 2 / dots) * i + ringIndex * 0.35;
        canvas.drawCircle(
          Offset(
            center.dx + math.cos(angle) * ringRadius,
            center.dy + math.sin(angle) * ringRadius,
          ),
          dotRadius * (1 - ringIndex * 0.12),
          dotPaint,
        );
      }
    }

    canvas.drawCircle(center, dotRadius * 1.1, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SunflowerHeadPainter oldDelegate) {
    return oldDelegate.active != active;
  }
}
