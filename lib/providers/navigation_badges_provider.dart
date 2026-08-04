import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/chat_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/veterinary_request_repository.dart';
import '../utils/order_status.dart';

final newSellerOrdersCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  return ref.watch(orderRepositoryProvider).watchSellerOrders(uid).map(
        (orders) =>
            orders.where((o) => o.statusCode == OrderStatus.newOrder).length,
      );
});

final pendingVetIntakesCountProvider = Provider.autoDispose<int>((ref) {
  final requests = ref.watch(vetIncomingRequestsProvider).value ?? const [];
  return requests
      .where((r) => r.status.toLowerCase() == 'pending')
      .length;
});

final navigationBadgesProvider = Provider.autoDispose<NavigationBadges>((ref) {
  final unreadMessages = ref.watch(unreadMessagesCountProvider).value ?? 0;
  final newOrders = ref.watch(newSellerOrdersCountProvider).value ?? 0;
  final pendingVetIntakes = ref.watch(pendingVetIntakesCountProvider);

  return NavigationBadges(
    unreadMessages: unreadMessages,
    newOrders: newOrders,
    pendingVetIntakes: pendingVetIntakes,
  );
});

class NavigationBadges {
  final int unreadMessages;
  final int newOrders;
  final int pendingVetIntakes;

  const NavigationBadges({
    this.unreadMessages = 0,
    this.newOrders = 0,
    this.pendingVetIntakes = 0,
  });

  int get sellerTabBadge => newOrders + unreadMessages;

  int get profileTabBadge => unreadMessages + pendingVetIntakes;
}
