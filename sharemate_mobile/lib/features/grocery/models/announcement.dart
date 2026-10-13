class GroceryAnnouncement {
  const GroceryAnnouncement({
    required this.id,
    required this.shopperId,
    required this.shopperName,
    required this.supermarket,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String shopperId;
  final String shopperName;
  final String supermarket;
  final String message;
  final String status;
  final String createdAt;
  final String expiresAt;

  factory GroceryAnnouncement.fromJson(Map<String, dynamic> json) {
    return GroceryAnnouncement(
      id: json['id'] as String? ?? '',
      shopperId: json['shopper_id'] as String? ?? '',
      shopperName: json['shopper_name'] as String? ?? 'Student',
      supermarket: json['supermarket'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
    );
  }

  factory GroceryAnnouncement.fromFirestore(Map<String, dynamic> data, String docId) {
    String ts(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      try {
        return (v as dynamic).toDate().toIso8601String();
      } catch (_) {
        return v.toString();
      }
    }

    return GroceryAnnouncement(
      id: data['id'] as String? ?? docId,
      shopperId: data['shopper_id'] as String? ?? '',
      shopperName: data['shopper_name'] as String? ?? 'Student',
      supermarket: data['supermarket'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      createdAt: ts(data['created_at']),
      expiresAt: ts(data['expires_at']),
    );
  }
}
