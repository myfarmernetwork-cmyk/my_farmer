import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRoleSlice {
  const AdminRoleSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class AdminUsageDay {
  const AdminUsageDay({
    required this.label,
    required this.registrations,
    required this.orders,
    required this.scans,
  });

  final String label;
  final int registrations;
  final int orders;
  final int scans;
}

List<DateTime> adminLast7Days() {
  final now = DateTime.now();
  return List.generate(7, (index) {
    final day = now.subtract(Duration(days: 6 - index));
    return DateTime(day.year, day.month, day.day);
  });
}

int adminCountDocsOnDay(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  DateTime day,
) {
  return docs.where((doc) {
    final createdAt = doc.data()['createdAt'] as Timestamp?;
    if (createdAt == null) return false;
    final date = createdAt.toDate();
    return date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }).length;
}

List<AdminUsageDay> adminBuildUsageDays({
  required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> scans,
}) {
  return adminLast7Days().map((day) {
    final label = '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.';
    return AdminUsageDay(
      label: label,
      registrations: adminCountDocsOnDay(users, day),
      orders: adminCountDocsOnDay(orders, day),
      scans: adminCountDocsOnDay(scans, day),
    );
  }).toList();
}

class AdminChartCard extends StatelessWidget {
  const AdminChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class AdminUserPieChart extends StatelessWidget {
  const AdminUserPieChart({super.key, required this.slices});

  final List<AdminRoleSlice> slices;

  @override
  Widget build(BuildContext context) {
    final active = slices.where((s) => s.value > 0).toList();
    final total = active.fold<int>(0, (sum, s) => sum + s.value);

    if (total == 0) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Nema podataka o korisnicima.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _PieChartPainter(slices: active, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'ukupno',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: active
              .map(
                (slice) => _LegendDot(
                  color: slice.color,
                  label: '${slice.label} (${slice.value})',
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class AdminUsageBarChart extends StatelessWidget {
  const AdminUsageBarChart({super.key, required this.days});

  final List<AdminUsageDay> days;

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<int>(0, (max, day) {
      final peak = [day.registrations, day.orders, day.scans]
          .fold<int>(0, (m, v) => v > m ? v : m);
      return peak > max ? peak : max;
    });

    if (maxValue == 0) {
      return SizedBox(
        height: 210,
        child: Center(
          child: Text(
            'Nema aktivnosti u zadnjih 7 dana.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          width: double.infinity,
          child: CustomPaint(
            painter: _UsageBarChartPainter(days: days, maxValue: maxValue),
          ),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _LegendDot(color: Color(0xFF1976D2), label: 'Registracije'),
            _LegendDot(color: Color(0xFF3949AB), label: 'Narudžbe'),
            _LegendDot(color: Color(0xFF388E3C), label: 'AI skenovi'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({required this.slices, required this.total});

  final List<AdminRoleSlice> slices;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 8;
    var startAngle = -3.1415926535 / 2;

    for (final slice in slices) {
      final sweep = (slice.value / total) * 3.1415926535 * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.total != total;
  }
}

class _UsageBarChartPainter extends CustomPainter {
  _UsageBarChartPainter({required this.days, required this.maxValue});

  final List<AdminUsageDay> days;
  final int maxValue;

  static const _barColors = [
    Color(0xFF1976D2),
    Color(0xFF3949AB),
    Color(0xFF388E3C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPadding = 28.0;
    const topPadding = 8.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final groupWidth = size.width / days.length;
    const barWidth = 8.0;
    const gap = 3.0;

    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - bottomPadding),
      Offset(size.width, size.height - bottomPadding),
      axisPaint,
    );

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final values = [day.registrations, day.orders, day.scans];
      final groupCenter = groupWidth * i + groupWidth / 2;
      final totalBarsWidth = barWidth * 3 + gap * 2;
      var x = groupCenter - totalBarsWidth / 2;

      for (var j = 0; j < values.length; j++) {
        final value = values[j];
        final barHeight = maxValue == 0 ? 0.0 : (value / maxValue) * chartHeight;
        final top = size.height - bottomPadding - barHeight;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = _barColors[j],
        );
        x += barWidth + gap;
      }

      final labelPainter = TextPainter(
        text: TextSpan(
          text: day.label,
          style: TextStyle(fontSize: 10, color: Colors.grey[700]),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupWidth);
      labelPainter.paint(
        canvas,
        Offset(groupCenter - labelPainter.width / 2, size.height - bottomPadding + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UsageBarChartPainter oldDelegate) {
    return oldDelegate.days != days || oldDelegate.maxValue != maxValue;
  }
}
