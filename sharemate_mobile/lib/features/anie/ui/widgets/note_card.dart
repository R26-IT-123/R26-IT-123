import 'package:flutter/material.dart';

import '../../models/note.dart';
import 'level_badge.dart';
import 'uploader_avatar.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.currentUserId,
    this.onTap,
    this.onLikeTap,
    this.onCommentTap,
  });

  final AnieNote note;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color:      Color(0x08000000),
              blurRadius: 12,
              offset:     Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Score circle
            Container(
              width:  54,
              height: 54,
              decoration: BoxDecoration(
                color:        _scoreBg(note.score),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    note.score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w900,
                      color:      _scoreColor(note.score),
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 9,
                      color:    _scoreColor(note.score),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${note.subject} · ${note.topic}',
                    style: const TextStyle(
                      fontSize: 11,
                      color:    Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _UploaderLabel(
                    isOwn:    note.uploaderId == currentUserId,
                    name:     note.uploaderName,
                    photoUrl: note.uploaderPhotoUrl,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      LevelBadge(level: note.level),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.download_rounded,
                        size:  12,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${note.downloadCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color:    Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SocialAction(
                        icon: note.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: note.likedByMe
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF9CA3AF),
                        label:   '${note.likeCount}',
                        onTap:   onLikeTap,
                      ),
                      const SizedBox(width: 18),
                      _SocialAction(
                        icon:      Icons.mode_comment_outlined,
                        iconColor: const Color(0xFF9CA3AF),
                        label:     '${note.commentCount}',
                        onTap:     onCommentTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (note.topicPdfUrl != null)
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFF2563EB),
                size:  20,
              ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 65) return const Color(0xFF166534);
    if (s >= 40) return const Color(0xFF92400E);
    return const Color(0xFF991B1B);
  }

  Color _scoreBg(double s) {
    if (s >= 65) return const Color(0xFFDCFCE7);
    if (s >= 40) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }
}

class _SocialAction extends StatelessWidget {
  const _SocialAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:    onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploaderLabel extends StatelessWidget {
  const _UploaderLabel({
    required this.isOwn,
    required this.name,
    this.photoUrl,
  });

  final bool   isOwn;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UploaderAvatar(name: name, photoUrl: photoUrl, radius: 7),
        const SizedBox(width: 5),
        if (isOwn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Yours',
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w700,
                color:      Color(0xFF1D4ED8),
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
