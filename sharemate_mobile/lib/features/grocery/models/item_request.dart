class GroceryItemRequest {
  const GroceryItemRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.supermarket,
    required this.items,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final String supermarket;
  final List<Map<String, dynamic>> items;
  final String note;
  final String status;
  final String createdAt;
  final String expiresAt;

  factory GroceryItemRequest.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> itemList = [];
    if (json['items'] != null) {
      itemList = (json['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return GroceryItemRequest(
      id:            json['id'] as String? ?? '',
      requesterId:   json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? 'Student',
      supermarket:   json['supermarket'] as String? ?? '',
      items:         itemList,
      note:          json['note'] as String? ?? '',
      status:        json['status'] as String? ?? 'open',
      createdAt:     json['created_at'] as String? ?? '',
      expiresAt:     json['expires_at'] as String? ?? '',
    );
  }
}
