import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final bg = backgroundColor ?? Colors.grey.shade200;
    final icon = Icon(
      Icons.person,
      color: iconColor ?? Colors.green.shade700,
      size: iconSize ?? radius * 1.1,
    );

    if (url == null || url.isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: icon);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => icon,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: radius * 1.2,
              height: radius * 1.2,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconColor ?? Colors.green.shade700,
              ),
            );
          },
        ),
      ),
    );
  }
}
