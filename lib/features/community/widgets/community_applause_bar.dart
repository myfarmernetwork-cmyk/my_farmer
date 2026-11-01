import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../repositories/community_post_repository.dart';
import '../../../widgets/sunflower_applause_icon.dart';
import '../../../theme/agro_accent_colors.dart';

class CommunityApplauseBar extends StatefulWidget {
  const CommunityApplauseBar({
    super.key,
    required this.post,
    required this.postRepository,
  });

  final CommunityPost post;
  final CommunityPostRepository postRepository;

  @override
  State<CommunityApplauseBar> createState() => _CommunityApplauseBarState();
}

class _CommunityApplauseBarState extends State<CommunityApplauseBar> {
  bool _toggling = false;
  late List<String> _applaudedBy;

  @override
  void initState() {
    super.initState();
    _applaudedBy = _dedupeUserIds(widget.post.applaudedBy);
  }

  @override
  void didUpdateWidget(covariant CommunityApplauseBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_toggling) return;
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.applaudedBy != widget.post.applaudedBy) {
      _applaudedBy = _dedupeUserIds(widget.post.applaudedBy);
    }
  }

  static List<String> _dedupeUserIds(List<String> ids) {
    final seen = <String>{};
    final unique = <String>[];
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      unique.add(trimmed);
    }
    return unique;
  }

  bool _hasApplauded(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return _applaudedBy.contains(userId);
  }

  void _applyApplauseChange({
    required String userId,
    required bool applaud,
  }) {
    if (applaud) {
      if (!_applaudedBy.contains(userId)) {
        _applaudedBy.add(userId);
      }
    } else {
      _applaudedBy.remove(userId);
    }
    _applaudedBy = _dedupeUserIds(_applaudedBy);
  }

  Future<void> _toggleApplause() async {
    if (_toggling) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('community_applause_login_required'.tr())),
      );
      return;
    }

    final currentlyApplauded = _hasApplauded(user.uid);
    _toggling = true;
    setState(() {
      _applyApplauseChange(userId: user.uid, applaud: !currentlyApplauded);
    });

    try {
      await widget.postRepository.toggleApplause(
        postId: widget.post.id,
        userId: user.uid,
        currentlyApplauded: currentlyApplauded,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _applyApplauseChange(userId: user.uid, applaud: currentlyApplauded);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _toggling = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final hasApplauded = _hasApplauded(userId);
    final count = _applaudedBy.length;
    const activeColor = AgroAccentColors.marketplaceChipGreen;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Material(
            color: hasApplauded
                ? activeColor.withValues(alpha: 0.10)
                : Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: hasApplauded
                    ? activeColor.withValues(alpha: 0.45)
                    : Colors.amber.shade300,
              ),
            ),
            child: InkWell(
              onTap: _toggling ? null : _toggleApplause,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_toggling)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: activeColor,
                        ),
                      )
                    else
                      SunflowerApplauseIcon(
                        active: hasApplauded,
                        size: 28,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'community_applause'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: hasApplauded ? activeColor : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 10),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: hasApplauded ? activeColor : Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
