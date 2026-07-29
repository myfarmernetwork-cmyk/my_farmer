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
}
