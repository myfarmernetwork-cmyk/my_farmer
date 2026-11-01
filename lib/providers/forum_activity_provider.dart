import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/forum/models/forum_category.dart';

/// Kategorije foruma s novom aktivnošću (točka, bez broja).
class ForumActivityNotifier extends StateNotifier<Set<ForumCategory>> {
  ForumActivityNotifier() : super({});

  void markCategoryActive(ForumCategory category) {
    if (state.contains(category)) return;
    state = {...state, category};
  }

  void markCategorySeen(ForumCategory category) {
    if (!state.contains(category)) return;
    final next = {...state}..remove(category);
    state = next;
  }

  bool get hasAnyActivity => state.isNotEmpty;
}

final forumActivityProvider =
    StateNotifierProvider<ForumActivityNotifier, Set<ForumCategory>>(
  (ref) => ForumActivityNotifier(),
);

final forumHasActivityProvider = Provider<bool>((ref) {
  return ref.watch(forumActivityProvider).isNotEmpty;
});
