import 'package:flutter/material.dart';

import '../theme/agro_accent_colors.dart';
import '../utils/chat_time_formatter.dart';

class ChatDaySeparator extends StatelessWidget {
  const ChatDaySeparator({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.white.withValues(alpha: 0.22);
    final textColor = AgroAccentColors.cardTextLight.withValues(alpha: 0.70);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              ChatTimeFormatter.daySeparatorLabel(context, date),
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor)),
        ],
      ),
    );
  }
}
