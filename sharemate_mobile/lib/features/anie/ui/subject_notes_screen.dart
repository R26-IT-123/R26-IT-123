import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/anie_api_service.dart';
import 'note_detail_screen.dart';
import 'widgets/note_card.dart';
import 'widgets/note_comments_sheet.dart';

class SubjectNotesScreen extends StatefulWidget {
  const SubjectNotesScreen({super.key, required this.subject});

  final String subject;

  @override
  State<SubjectNotesScreen> createState() => _SubjectNotesScreenState();
}

class _SubjectNotesScreenState extends State<SubjectNotesScreen> {
  final _service = AnieApiService();
  final _searchCtrl = TextEditingController();

  List<AnieNote> _notes = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final notes = await _service.fetchNotes(subject: widget.subject);
      if (mounted) setState(() => _notes = notes);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AnieNote> get _visibleNotes {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _notes;
    return _notes.where((n) {
      return n.title.toLowerCase().contains(query) ||
          n.topic.toLowerCase().contains(query) ||
          n.uploaderName.toLowerCase().contains(query);
    }).toList();
  }

  void _replaceNote(AnieNote updated) {
    setState(() {
      _notes = [
        for (final n in _notes)
          if (n.noteId == updated.noteId) updated else n,
      ];
    });
  }

  Future<void> _toggleLike(AnieNote note) async {
    final optimistic = note.copyWith(
      likedByMe: !note.likedByMe,
      likeCount: note.likedByMe ? note.likeCount - 1 : note.likeCount + 1,
    );
    _replaceNote(optimistic);
    try {
      final result = await _service.toggleLike(note.noteId);
      _replaceNote(optimistic.copyWith(
        likedByMe: result.liked,
        likeCount: result.likeCount,
      ));
    } catch (_) {
      _replaceNote(note); // revert on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like. Try again.')),
        );
      }
    }
  }

  void _openComments(AnieNote note) {
    showModalBottomSheet(
      context:        context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteCommentsSheet(
        note: note,
        api:  _service,
        onCommentCountChanged: (count) {
          final current = _notes.firstWhere(
            (n) => n.noteId == note.noteId,
            orElse: () => note,
          );
          _replaceNote(current.copyWith(commentCount: count));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:        0,
        foregroundColor:  const Color(0xFF111827),
        title: Text(
          widget.subject,
          style: const TextStyle(
            fontSize:   17,
            fontWeight: FontWeight.w800,
            color:      Color(0xFF111827),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotes,
        color:     const Color(0xFF2563EB),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged:  (q) => setState(() => _searchQuery = q),
                  decoration: InputDecoration(
                    hintText:   'Search notes by title or topic…',
                    hintStyle:  const TextStyle(
                      color:    Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF9CA3AF)),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF9CA3AF)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    filled:     true,
                    fillColor:  Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:   const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              )
            else if (_visibleNotes.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _searchCtrl.text.isEmpty
                            ? Icons.menu_book_rounded
                            : Icons.search_off_rounded,
                        size:  60,
                        color: const Color(0xFFD1D5DB),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchCtrl.text.isEmpty
                            ? 'No notes yet for ${widget.subject}'
                            : 'No notes match your search',
                        style: const TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.w700,
                          color:      Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchCtrl.text.isEmpty
                            ? 'Be the first to share a note!'
                            : 'Try a different keyword.',
                        style: const TextStyle(
                          fontSize: 13,
                          color:    Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => NoteCard(
                      note:          _visibleNotes[i],
                      currentUserId: currentUserId,
                      onTap:         () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                NoteDetailScreen(note: _visibleNotes[i]),
                          ),
                        );
                      },
                      onLikeTap:    () => _toggleLike(_visibleNotes[i]),
                      onCommentTap: () => _openComments(_visibleNotes[i]),
                    ),
                    childCount: _visibleNotes.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
