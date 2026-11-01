import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/forum/models/forum_category.dart';
import '../features/forum/models/forum_topic.dart';
import '../features/forum/repositories/forum_repository.dart';
import '../features/forum/screens/forum_create_topic_screen.dart';
import '../features/forum/screens/forum_topic_detail_screen.dart';
import '../features/forum/utils/forum_author_name.dart';
import '../providers/forum_activity_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/forum_seen_prefs.dart';
import '../widgets/farmer_help_widgets.dart';
import '../models/screen_guide_step.dart';
import '../widgets/farmer_helper_button.dart';
import '../utils/scroll_bottom_padding.dart';
import '../theme/agro_accent_colors.dart';
import '../widgets/agro_glass_chrome.dart';

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen>
    with SingleTickerProviderStateMixin {
  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;
  static const _priceYellow = Color(0xFFFFEB3B);

  final ForumRepository _repository = ForumRepository();
  late final TabController _tabController;

  final GlobalKey _guideCategoriesKey = GlobalKey();
  final GlobalKey _guideFabKey = GlobalKey();
  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guideCategoriesKey,
          titleKey: 'guide_forum_categories_title',
          bodyKey: 'guide_forum_categories_body',
        ),
        ScreenGuideStep(
          targetKey: _guideFabKey,
          titleKey: 'guide_forum_add_title',
          bodyKey: 'guide_forum_add_body',
          highlightLabelKey: 'forum_new_topic',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: ForumCategory.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _markCurrentCategorySeen();
  }

  Future<void> _markCurrentCategorySeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final category = ForumCategory.values[_tabController.index];
    await ForumSeenPrefs.markSeen(uid, category);
    ref.read(forumActivityProvider.notifier).markCategorySeen(category);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _markCurrentCategorySeen();
    _tabController.dispose();
    super.dispose();
  }
  void _openCreateTopic(ForumCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumCreateTopicScreen(category: category),
      ),
    );
  }

  String _categoryLabel(ForumCategory category) {
    final key = category.labelKey;
    final translated = key.tr();
    if (translated != key) return translated;
    return farmerGuideTr(context, key);
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = ref.watch(forumActivityProvider);

    return Scaffold(
      key: ValueKey('forum_screen_${context.locale}'),
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('forum_title'.tr()),
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            key: _guideCategoriesKey,
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
            tabs: ForumCategory.values
                .map(
                  (category) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_categoryLabel(category)),
                        if (activeCategories.contains(category)) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.amberAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: TabBarView(
          controller: _tabController,
          children: ForumCategory.values
              .map(
                (category) => _CategoryTopicsList(
                  category: category,
                  repository: _repository,
                ),
              )
              .toList(),
        ),
      ),
      floatingActionButtonLocation: ScrollBottomPadding.fabLocationForum,
      floatingActionButton: FloatingActionButton.extended(
        key: _guideFabKey,
        heroTag: 'forum_new_topic_fab',
        onPressed: () {
          final category = ForumCategory.values[_tabController.index];
          _openCreateTopic(category);
        },
        backgroundColor: _chipGreen,
        foregroundColor: _priceYellow,
        icon: const Icon(Icons.add_comment),
        label: Text(
          farmerGuideTr(context, 'forum_new_topic'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CategoryTopicsList extends ConsumerStatefulWidget {
  const _CategoryTopicsList({
    required this.category,
    required this.repository,
  });

  final ForumCategory category;
  final ForumRepository repository;

  @override
  ConsumerState<_CategoryTopicsList> createState() =>
      _CategoryTopicsListState();
}

class _CategoryTopicsListState extends ConsumerState<_CategoryTopicsList> {
  List<ForumTopic> _topics = const [];
  Map<String, String> _authorNames = const {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final topics = await widget.repository.fetchTopics(widget.category);
    final ids = topics.map((t) => t.authorId).where((id) => id.isNotEmpty).toSet();
    final names = await ForumAuthorName.forUserIds(ids);
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _authorNames = names;
      _loaded = true;
    });
  }

  String _authorLabel(ForumTopic topic) {
    final resolved = _authorNames[topic.authorId];
    return ForumAuthorName.label(
      resolved?.isNotEmpty == true ? resolved! : topic.authorName,
      'forum_anonymous'.tr(),
    );
  }

  Future<void> _editTopic(ForumTopic topic) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumCreateTopicScreen(
          category: topic.category,
          editingTopic: topic,
        ),
      ),
    );
    if (changed == true) await _loadTopics();
  }

  Future<void> _deleteTopic(ForumTopic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('forum_delete_topic'.tr()),
        content: Text('forum_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'forum_delete_action'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.deleteTopic(topic.id);
      await _loadTopics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openTopic(ForumTopic topic) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumTopicDetailScreen(topicId: topic.id),
      ),
    );
    if (changed == true) await _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(
          color: AgroAccentColors.marketplaceChipGreen,
        ),
      );
    }

    if (_topics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'forum_empty_category'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AgroAccentColors.marketplaceChipGreen,
      onRefresh: _loadTopics,
      child: ListView.separated(
        padding: ScrollBottomPadding.list(context, mainTab: true),
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final topic = _topics[index];
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final isOwn = uid != null && topic.authorId == uid;
          final isForumAdmin = ref.watch(adminPremiumBypassProvider);
          final canModerateTopic = isOwn || isForumAdmin;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AgroAccentColors.marketplaceCornerRadius,
                ),
                side: BorderSide(
                  color: AgroAccentColors.marketplaceChipGreen
                      .withValues(alpha: 0.22),
                ),
              ),
              child: InkWell(
                onTap: () => _openTopic(topic),
                borderRadius: BorderRadius.circular(
                  AgroAccentColors.marketplaceCornerRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AgroAccentColors.marketplaceChipGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topic.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_authorLabel(topic)} · ${topic.commentCount} ${'forum_comments_short'.tr()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canModerateTopic)
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: AgroAccentColors.marketplaceChipGreen,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editTopic(topic);
                                } else if (value == 'delete') {
                                  _deleteTopic(topic);
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (isOwn)
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined, size: 18),
                                        const SizedBox(width: 8),
                                        Text('forum_edit_topic'.tr()),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red.shade700),
                                      const SizedBox(width: 8),
                                      Text(
                                        'forum_delete_topic'.tr(),
                                        style:
                                            TextStyle(color: Colors.red.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (topic.imageUrl != null &&
                              topic.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                topic.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AgroAccentColors.marketplaceChipGreen,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
