import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/order_repository.dart';
import '../repositories/review_repository.dart';
import '../theme/agro_accent_colors.dart';

Future<void> showFarmerReviewPrompt(
  BuildContext context,
  WidgetRef ref, {
  required String sellerId,
}) async {
  final normalizedSellerId = sellerId.trim();
  if (normalizedSellerId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('product_review_purchase_required'.tr())),
    );
    return;
  }

  final reviewRepo = ref.read(reviewRepositoryProvider);
  final orderRepo = ref.read(orderRepositoryProvider);
  final alreadyReviewed = await reviewRepo.hasReviewed(normalizedSellerId);

  if (!context.mounted) return;

  if (alreadyReviewed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('product_already_reviewed'.tr())),
    );
    return;
  }

  final hasPurchased =
      await orderRepo.hasCompletedOrderFromSeller(normalizedSellerId);
  if (!context.mounted) return;

  if (!hasPurchased) {
    final messageKey = await orderRepo.reviewBlockMessageKey(normalizedSellerId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messageKey.tr())),
    );
    return;
  }

  double selectedRating = 5;
  final commentController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: StatefulBuilder(
              builder: (context, setModalState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'product_rate_farmer'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedRating = index + 1.0),
                        child: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'product_review_comment'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AgroAccentColors.marketplaceChipGreen,
                      foregroundColor: const Color(0xFFFFEB3B),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        await reviewRepo.addReview(
                          sellerId: normalizedSellerId,
                          rating: selectedRating,
                          comment: commentController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('product_review_thanks'.tr()),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        final message = e.toString().contains(
                              'product_review_purchase_required',
                            )
                            ? 'product_review_purchase_required'.tr()
                            : 'common_error'.tr(
                                namedArgs: {'error': '$e'},
                              );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text('product_send_review'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  commentController.dispose();
}
