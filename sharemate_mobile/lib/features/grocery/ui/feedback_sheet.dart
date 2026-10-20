import 'package:flutter/material.dart';

import '../services/grocery_api_service.dart';

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({
    super.key,
    required this.chatId,
    required this.otherPersonName,
    required this.service,
  });

  final String chatId;
  final String otherPersonName;
  final GroceryApiService service;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  static const _accent = Color(0xFFBE185D);
  static const _gold = Color(0xFFF59E0B);

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.service.submitFeedback(
        chatId: widget.chatId,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: _gold, size: 30),
          ),
          const SizedBox(height: 16),

          const Text(
            'Rate your experience',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            'How was your shopping experience with ${widget.otherPersonName}?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: starValue <= _rating ? _gold : const Color(0xFFD1D5DB),
                    size: 44,
                  ),
                ),
              );
            }),
          ),

          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _ratingLabel(_rating),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gold),
            ),
          ],

          const SizedBox(height: 20),

          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)…',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: (_rating == 0 || _submitting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit Feedback',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent!';
      default: return '';
    }
  }
}
