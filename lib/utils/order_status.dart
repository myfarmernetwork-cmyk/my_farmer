/// Canonical Firestore order status codes (legacy Croatian strings are normalized on read).
class OrderStatus {
  static const newOrder = 'new';
  static const preparing = 'preparing';
  static const completed = 'completed';

  static const flow = [newOrder, preparing, completed];

  static String normalize(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'new':
      case 'novo':
      case 'na čekanju':
      case 'pending':
        return newOrder;
      case 'preparing':
      case 'u pripremi':
      case 'in_progress':
      case 'processing':
        return preparing;
      case 'completed':
      case 'isporučeno':
      case 'završeno':
      case 'zavrseno':
      case 'odrađeno':
      case 'odradeno':
      case 'delivered':
      case 'done':
      case 'finished':
        return completed;
      default:
        if (raw == null || raw.toString().isEmpty) return newOrder;
        return newOrder;
    }
  }

  static bool isActive(String code) =>
      code == newOrder || code == preparing;

  static bool isHistory(String code) => code == completed;

  static String? nextCode(String code) {
    final index = flow.indexOf(code);
    if (index < 0 || index >= flow.length - 1) return null;
    return flow[index + 1];
  }

  static String labelKey(String code) {
    switch (code) {
      case newOrder:
        return 'orders_status_new';
      case preparing:
        return 'orders_status_preparing';
      case completed:
        return 'orders_status_completed';
      default:
        return 'orders_status_new';
    }
  }

  /// Completed label depends on pickup vs delivery.
  static String completedLabelKey(String deliveryType) {
    return deliveryType == 'delivery'
        ? 'orders_status_ready_delivery'
        : 'orders_status_ready_pickup';
  }

  /// Seller action button for advancing from [currentCode].
  static String? nextActionLabelKey(String currentCode, String deliveryType) {
    final next = nextCode(currentCode);
    if (next == null) return null;
    switch (next) {
      case preparing:
        return 'orders_action_accept';
      case completed:
        return deliveryType == 'delivery'
            ? 'orders_action_mark_ready_delivery'
            : 'orders_action_mark_ready_pickup';
      default:
        return 'orders_next_step';
    }
  }

  static String flowStepLabelKey(String code) {
    switch (code) {
      case newOrder:
        return 'orders_flow_step_new';
      case preparing:
        return 'orders_flow_step_preparing';
      case completed:
        return 'orders_flow_step_ready';
      default:
        return 'orders_flow_step_new';
    }
  }

  static String sellerHintKey(String code) {
    switch (code) {
      case newOrder:
        return 'orders_seller_step_hint_new';
      case preparing:
        return 'orders_seller_step_hint_preparing';
      default:
        return '';
    }
  }
}
