import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/anie_api_service.dart';
import 'widgets/level_badge.dart';

class ScoreResultScreen extends StatefulWidget {
  const ScoreResultScreen({
    super.key,
    required this.result,
  });

  final ValidateNoteResult result;

  @override
  State<ScoreResultScreen> createState() => _ScoreResultScreenState();
}

class _ScoreResultScreenState extends State<ScoreResultScreen>
    with SingleTickerProviderStateMixin {
  final _service = AnieApiService();

  bool _publishing = false;
  bool _published  = false;
  String? _topicPdfUrl;
  int?    _tokensAwarded;

  late final AnimationController _scoreCtrl;
  late final Animation<double>   _scoreAnim;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.result.score).animate(
      CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut),
    );
    _scoreCtrl.forward();
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final resp = await _service.generateTopicPdf(widget.result.noteId);
      setState(() {
        _published     = true;
        _topicPdfUrl   = resp['topic_pdf_url'] as String?;
        _tokensAwarded = (resp['tokens_earned'] as num?)?.toInt();
      });
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      appBar: AppBar(
        backgroundColor:  Colors.white,
        elevation:        0,
        title: const Text(
          'AI Score Result',
          style: TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.w800,
            color:      Color(0xFF111827),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF374151)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _published ? _PublishedView(
        tokensAwarded: _tokensAwarded ?? r.tokensEarned,
        topicPdfUrl:   _topicPdfUrl,
        onDone:        () => Navigator.of(context).pop(true),
      ) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score card
            _ScoreCard(scoreAnim: _scoreAnim, result: r),
            const SizedBox(height: 16),

            // // Keywords found
            // if (r.keywordsFound.isNotEmpty) ...[
            //   _KeywordsCard(keywords: r.keywordsFound),
            //   const SizedBox(height: 16),
            // ],

            // Warning
            if (r.warning != null) ...[
              _WarningCard(message: r.warning!),
              const SizedBox(height: 16),
            ],

            // Rejection reason
            if (!r.isApproved && r.rejectionReason != null) ...[
              _RejectionCard(reason: r.rejectionReason!),
              const SizedBox(height: 20),
            ],

            // Action buttons
            if (r.isApproved) ...[
              _TokenPreview(tokens: r.tokensEarned),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _publishing ? null : _publish,
                  icon: _publishing
                      ? const SizedBox(
                          width:  18,
                          height: 18,
                          child:  CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: Text(
                    _publishing ? 'Generating Topic PDF…' : 'Publish Note',
                    style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side:  const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      fontSize:   16,
                      color:      Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width:  double.infinity,
                height: 52,
                child:  FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  icon:  const Icon(Icons.upload_file_rounded),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.scoreAnim, required this.result});

  final Animation<double>   scoreAnim;
  final ValidateNoteResult  result;

  @override
  Widget build(BuildContext context) {
    final (barColor, bgColor) = _colors(result.score);

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Animated score circle
          AnimatedBuilder(
            animation: scoreAnim,
            builder: (_, __) {
              final v = scoreAnim.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width:  120,
                    height: 120,
                    child:  CircularProgressIndicator(
                      value:            v / 100,
                      strokeWidth:      10,
                      backgroundColor:  const Color(0xFFF3F4F6),
                      valueColor:       AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontSize:   36,
                          fontWeight: FontWeight.w900,
                          color:      barColor,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 13,
                          color:    Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LevelBadge(level: result.level, large: true),
          const SizedBox(height: 6),
          Text(
            '${result.levelConfidence.toStringAsFixed(0)}% confidence · ${result.wordCount} words',
            style: const TextStyle(
              fontSize: 12,
              color:    Color(0xFF9CA3AF),
            ),
          ),
          if (!result.isApproved) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Note did not reach the quality threshold',
                style: TextStyle(
                  fontSize:   12,
                  color:      Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _colors(double s) {
    if (s >= 65) return (const Color(0xFF16A34A), const Color(0xFFDCFCE7));
    if (s >= 40) return (const Color(0xFFD97706), const Color(0xFFFEF3C7));
    return (const Color(0xFFDC2626), const Color(0xFFFEE2E2));
  }
}

// // ── Keywords card ─────────────────────────────────────────────────────────────

// class _KeywordsCard extends StatelessWidget {
//   const _KeywordsCard({required this.keywords});

//   final List<String> keywords;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width:   double.infinity,
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Domain Keywords Found',
//             style: TextStyle(
//               fontSize:   14,
//               fontWeight: FontWeight.w700,
//               color:      Color(0xFF111827),
//             ),
//           ),
//           const SizedBox(height: 10),
//           Wrap(
//             spacing:   6,
//             runSpacing: 6,
//             children:  keywords.map((kw) => Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color:        const Color(0xFFDBEAFE),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 kw,
//                 style: const TextStyle(
//                   fontSize:   11,
//                   color:      Color(0xFF1D4ED8),
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             )).toList(),
//           ),
//         ],
//       ),
//     );
//   }
// }

// ── Warning ───────────────────────────────────────────────────────────────────

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color:    Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rejection ─────────────────────────────────────────────────────────────────

class _RejectionCard extends StatelessWidget {
  const _RejectionCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined,
              size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note Rejected',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 12,
                    color:    Color(0xFF991B1B),
                    height:   1.5,
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

// ── Token preview ─────────────────────────────────────────────────────────────

class _TokenPreview extends StatelessWidget {
  const _TokenPreview({required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.toll_rounded, color: Color(0xFF2563EB), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tokens you will earn',
                  style: TextStyle(
                    fontSize: 12,
                    color:    Color(0xFF3B82F6),
                  ),
                ),
                Text(
                  '+$tokens tokens',
                  style: const TextStyle(
                    fontSize:   20,
                    fontWeight: FontWeight.w900,
                    color:      Color(0xFF1D4ED8),
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

// ── Published view ────────────────────────────────────────────────────────────

class _PublishedView extends StatelessWidget {
  const _PublishedView({
    required this.tokensAwarded,
    required this.topicPdfUrl,
    required this.onDone,
  });

  final int       tokensAwarded;
  final String?   topicPdfUrl;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: const BoxDecoration(
                color:  Color(0xFFDCFCE7),
                shape:  BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF16A34A),
                size:  44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Note Published!',
              style: TextStyle(
                fontSize:   24,
                fontWeight: FontWeight.w900,
                color:      Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You earned +$tokensAwarded tokens',
              style: const TextStyle(
                fontSize:   16,
                color:      Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Topic PDF has been generated and is available for the community.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color:    Color(0xFF6B7280),
                height:   1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width:  double.infinity,
              height: 52,
              child:  FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onDone,
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
