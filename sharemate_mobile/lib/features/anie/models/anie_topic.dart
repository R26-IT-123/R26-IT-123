class AnieTopic {
  const AnieTopic({
    required this.subject,
    required this.topic,
    required this.chunks,
  });

  final String subject;
  final String topic;
  final int chunks;

  factory AnieTopic.fromJson(Map<String, dynamic> json) {
    return AnieTopic(
      subject: json['subject'] as String? ?? '',
      topic:   json['topic']   as String? ?? '',
      chunks:  (json['chunks'] as num?)?.toInt() ?? 0,
    );
  }
}
