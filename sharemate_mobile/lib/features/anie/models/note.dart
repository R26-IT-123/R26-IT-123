class AnieNote {
  const AnieNote({
    required this.noteId,
    required this.title,
    required this.subject,
    required this.topic,
    required this.score,
    required this.level,
    required this.uploaderId,
    required this.uploaderName,
    required this.downloadCount,
    required this.createdAt,
    this.topicPdfUrl,
    this.uploaderPhotoUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.purchasedByMe = false,
  });

  final String noteId;
  final String title;
  final String subject;
  final String topic;
  final double score;
  final String level;
  final String uploaderId;
  final String uploaderName;
  final int downloadCount;
  final String createdAt;
  final String? topicPdfUrl;
  final String? uploaderPhotoUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool purchasedByMe;

  factory AnieNote.fromJson(Map<String, dynamic> json) {
    return AnieNote(
      noteId:           json['note_id']        as String? ?? '',
      title:            json['title']          as String? ?? '',
      subject:          json['subject']        as String? ?? '',
      topic:            json['topic']          as String? ?? '',
      score:            (json['score']         as num?)?.toDouble() ?? 0,
      level:            json['level']          as String? ?? 'Beginner',
      uploaderId:       json['uploader_id']    as String? ?? '',
      uploaderName:     json['uploader_name']  as String? ?? 'Anonymous',
      downloadCount:    (json['download_count'] as num?)?.toInt() ?? 0,
      createdAt:        json['created_at']     as String? ?? '',
      topicPdfUrl:      json['topic_pdf_url']  as String?,
      uploaderPhotoUrl: json['uploader_photo_url'] as String?,
      likeCount:        (json['like_count']    as num?)?.toInt() ?? 0,
      commentCount:     (json['comment_count'] as num?)?.toInt() ?? 0,
      likedByMe:        json['liked_by_me']    as bool? ?? false,
      purchasedByMe:    json['purchased_by_me'] as bool? ?? false,
    );
  }

  AnieNote copyWith({
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    bool? purchasedByMe,
    String? topicPdfUrl,
  }) {
    return AnieNote(
      noteId:           noteId,
      title:            title,
      subject:          subject,
      topic:            topic,
      score:            score,
      level:            level,
      uploaderId:       uploaderId,
      uploaderName:     uploaderName,
      downloadCount:    downloadCount,
      createdAt:        createdAt,
      topicPdfUrl:      topicPdfUrl ?? this.topicPdfUrl,
      uploaderPhotoUrl: uploaderPhotoUrl,
      likeCount:        likeCount ?? this.likeCount,
      commentCount:     commentCount ?? this.commentCount,
      likedByMe:        likedByMe ?? this.likedByMe,
      purchasedByMe:    purchasedByMe ?? this.purchasedByMe,
    );
  }
}

class AnieNoteDetail {
  const AnieNoteDetail({
    required this.note,
    required this.extractedText,
    required this.noteWordCount,
    required this.originalUrls,
  });

  final AnieNote note;
  final String extractedText;
  final int noteWordCount;
  final List<String> originalUrls;

  factory AnieNoteDetail.fromJson(Map<String, dynamic> json) {
    return AnieNoteDetail(
      note:          AnieNote.fromJson(json),
      extractedText: json['extracted_text']   as String? ?? '',
      noteWordCount: (json['note_word_count'] as num?)?.toInt() ?? 0,
      originalUrls:  (json['original_urls'] as List<dynamic>?)
                         ?.map((e) => e.toString())
                         .toList() ?? [],
    );
  }
}

class AnieComment {
  const AnieComment({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String commentId;
  final String userId;
  final String userName;
  final String text;
  final String createdAt;

  factory AnieComment.fromJson(Map<String, dynamic> json) {
    return AnieComment(
      commentId: json['comment_id'] as String? ?? '',
      userId:    json['user_id']    as String? ?? '',
      userName:  json['user_name']  as String? ?? 'Anonymous',
      text:      json['text']       as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ValidateNoteResult {
  const ValidateNoteResult({
    required this.noteId,
    required this.score,
    required this.level,
    required this.levelConfidence,
    required this.isApproved,
    required this.tokensEarned,
    required this.keywordsFound,
    required this.wordCount,
    this.rejectionReason,
    this.warning,
  });

  final String noteId;
  final double score;
  final String level;
  final double levelConfidence;
  final bool isApproved;
  final int tokensEarned;
  final List<String> keywordsFound;
  final int wordCount;
  final String? rejectionReason;
  final String? warning;

  factory ValidateNoteResult.fromJson(Map<String, dynamic> json) {
    return ValidateNoteResult(
      noteId:           json['note_id']          as String? ?? '',
      score:            (json['score']            as num?)?.toDouble() ?? 0,
      level:            json['level']             as String? ?? 'Beginner',
      levelConfidence:  (json['level_confidence'] as num?)?.toDouble() ?? 0,
      isApproved:       json['is_approved']       as bool? ?? false,
      tokensEarned:     (json['tokens_earned']    as num?)?.toInt() ?? 0,
      keywordsFound:    (json['keywords_found']   as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ?? [],
      wordCount:        (json['word_count']       as num?)?.toInt() ?? 0,
      rejectionReason:  json['rejection_reason']  as String?,
      warning:          json['warning']           as String?,
    );
  }
}
