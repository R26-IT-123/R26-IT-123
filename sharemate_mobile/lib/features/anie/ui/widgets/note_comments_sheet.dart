import 'package:flutter/material.dart';

import '../../models/note.dart';
import '../../services/anie_api_service.dart';

class NoteCommentsSheet extends StatefulWidget {
  const NoteCommentsSheet({
    super.key,
    required this.note,
    required this.api,
    this.onCommentCountChanged,
  });

  final AnieNote note;
  final AnieApiService api;
  final void Function(int newCommentCount)? onCommentCountChanged;

  @override
  State<NoteCommentsSheet> createState() => _NoteCommentsSheetState();
}

class _NoteCommentsSheetState extends State<NoteCommentsSheet> {
  final _textCtrl = TextEditingController();

  List<AnieComment> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final comments = await widget.api.fetchComments(widget.note.noteId);
      if (mounted) setState(() => _comments = comments);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      final comment = await widget.api.postComment(widget.note.noteId, text);
      _textCtrl.clear();
      if (mounted) {
        setState(() => _comments = [..._comments, comment]);
        widget.onCommentCountChanged?.call(_comments.length);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      expand:           false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Comments (${_comments.length})',
                  style: const TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w800,
                    color:      Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2563EB)),
                        )
                      : _comments.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet. Be the first!',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF9CA3AF)),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              itemCount: _comments.length,
                              itemBuilder: (_, i) =>
                                  _CommentTile(comment: _comments[i]),
                            ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              hintStyle: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 13),
                              filled:    true,
                              fillColor: const Color(0xFFF3F4F6),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _posting
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2563EB)),
                                ),
                              )
                            : IconButton(
                                onPressed: _submit,
                                icon: const Icon(Icons.send_rounded,
                                    color: Color(0xFF2563EB)),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final AnieComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius:          16,
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              comment.userName.isNotEmpty
                  ? comment.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w800,
                color:      Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName,
                  style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color:    Color(0xFF374151),
                    height:   1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
