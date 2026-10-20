class RouteNotification {
  const RouteNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  factory RouteNotification.fromJson(Map<String, dynamic> json) {
    return RouteNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
