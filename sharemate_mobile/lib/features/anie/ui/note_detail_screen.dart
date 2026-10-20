import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/note.dart';
import '../services/anie_api_service.dart';
import 'image_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/level_badge.dart';
import 'widgets/uploader_avatar.dart';

const _imageExtensions = {'jpg', 'jpeg', 'png', 'bmp', 'tiff', 'tif', 'webp'};

String _fileExtension(String url) {
  final withoutQuery = url.split('?').first;
  final dotIndex     = withoutQuery.lastIndexOf('.');
  if (dotIndex == -1) return '';
  return withoutQuery.substring(dotIndex + 1).toLowerCase();
}

String _fileName(String url, int index) {
  final withoutQuery = url.split('?').first;
  final decoded       = Uri.decodeFull(withoutQuery);
  final lastSegment   = decoded.split('/').last;
  return lastSegment.isEmpty ? 'File ${index + 1}' : lastSegment;
}

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.note});

  final AnieNote note;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _service = AnieApiService();
  final _scrollController = ScrollController();

  AnieNoteDetail? _detail;
  bool _loading = true;
  bool _error   = false;
  int? _downloadCount;
  bool _purchasing = false;
  bool _scrolledDown = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final scrolledDown = _scrollController.offset > 200;
    if (scrolledDown != _scrolledDown) {
      setState(() => _scrolledDown = scrolledDown);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error   = false;
    });
    try {
      final detail = await _service.fetchNoteDetail(widget.note.noteId);
      if (mounted) {
        setState(() {
          _detail        = detail;
          _downloadCount = detail.note.downloadCount;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase() async {
    setState(() => _purchasing = true);
    try {
      await _service.purchaseNote(widget.note.noteId);
      await _loadDetail(); // refetch — server now includes the unlocked fields
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note unlocked — 1 token used.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 402
                ? 'Not enough tokens. Publish a note to earn more.'
                : 'Could not unlock note: ${e.message}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not unlock note. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _openPdf(String url) async {
    try {
      final count = await _service.incrementDownload(widget.note.noteId);
      if (mounted) setState(() => _downloadCount = count);
    } catch (_) {
      // count bump is best-effort; still let the user view the PDF
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(url: url, title: widget.note.title),
      ),
    );
  }

  Future<void> _openOriginalFile(String url, String name) async {
    try {
      final count = await _service.incrementDownload(widget.note.noteId);
      if (mounted) setState(() => _downloadCount = count);
    } catch (_) {
      // count bump is best-effort; still let the user view the file
    }
    if (!mounted) return;
    final isImage = _imageExtensions.contains(_fileExtension(url));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isImage
            ? ImageViewerScreen(url: url, title: name)
            : PdfViewerScreen(url: url, title: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note   = widget.note;
    final locked = _detail != null && !_detail!.note.purchasedByMe;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: Text(note.title, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : _error || _detail == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load this note.',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width:  54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: _scoreBg(note.score),
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
                                        '${note.subject} · ${note.topic}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color:    Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          LevelBadge(level: note.level),
                                          const SizedBox(width: 8),
                                          UploaderAvatar(
                                            name:     note.uploaderName,
                                            photoUrl: note.uploaderPhotoUrl,
                                            radius:   8,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              note.uploaderName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 4),
                                Text('${note.likeCount}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF6B7280))),
                                const SizedBox(width: 16),
                                const Icon(Icons.mode_comment_outlined,
                                    size: 16, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 4),
                                Text('${note.commentCount}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF6B7280))),
                                const SizedBox(width: 16),
                                const Icon(Icons.download_rounded,
                                    size: 16, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 4),
                                Text('${_downloadCount ?? note.downloadCount}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Short Note',
                        style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w800,
                          color:      Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          locked
                              ? 'Unlock this note with 1 token to view the full content.'
                              : _detail!.extractedText.trim().isEmpty
                                  ? 'No text content available for this note.'
                                  : _detail!.extractedText,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height:   1.55,
                            color:    Color(0xFF374151),
                          ),
                        ),
                      ),
                      if (_detail!.originalUrls.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Uploaded File(s)',
                          style: TextStyle(
                            fontSize:   15,
                            fontWeight: FontWeight.w800,
                            color:      Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(_detail!.originalUrls.length, (i) {
                          final url      = _detail!.originalUrls[i];
                          final name     = _fileName(url, i);
                          final isImage  =
                              _imageExtensions.contains(_fileExtension(url));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color:        Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openOriginalFile(url, name),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isImage
                                            ? Icons.image_rounded
                                            : Icons.picture_as_pdf_rounded,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize:   13,
                                            fontWeight: FontWeight.w600,
                                            color:      Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.download_rounded,
                                        size:  18,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 20),
                      if (locked)
                        SizedBox(
                          width:  double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _purchasing ? null : _purchase,
                            icon: _purchasing
                                ? const SizedBox(
                                    width:  18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: const Text(
                              'Unlock for 1 Token',
                              style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else if (_detail!.note.topicPdfUrl != null)
                        SizedBox(
                          width:  double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () =>
                                _openPdf(_detail!.note.topicPdfUrl!),
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: const Text(
                              'View / Download PDF',
                              style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: _loading || _error || _detail == null
          ? null
          : FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              onPressed: _scrolledDown ? _scrollToTop : _scrollToBottom,
              child: Icon(
                _scrolledDown
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
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
