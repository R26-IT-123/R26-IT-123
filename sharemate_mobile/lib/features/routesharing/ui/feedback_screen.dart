import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/ride_session.dart';
import '../services/routesharing_api_service.dart';
import 'my_bookings_screen.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.sessionId,
    required this.driverId,
  });

  final String sessionId;
  final String driverId;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _api = RouteSharingApiService();
  final _commentCtrl = TextEditingController();

  double _rating = 0;
  bool _submitting = false;

  bool get _canSubmit =>
      _rating >= 1 && _commentCtrl.text.trim().isNotEmpty && !_submitting;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final feedback = RideFeedback(
        rideSessionId: widget.sessionId,
        driverId: widget.driverId,
        overallRating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      await _api.submitFeedback(feedback);
      if (!mounted) return;
      // Navigate to My Bookings, clearing the tracking + feedback screens
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
        (route) => route.isFirst,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to submit feedback. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const Text(
                    'Rate Your Ride',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // ── Star rating ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'How was your ride?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final starVal = i + 1.0;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _rating = starVal),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Icon(
                                    _rating >= starVal
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 48,
                                    color: _rating >= starVal
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFD1D5DB),
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_rating > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              _ratingLabel(_rating),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Comment ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share your experience',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Required — your feedback helps improve the service.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _commentCtrl,
                            maxLines: 4,
                            maxLength: 500,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Tell us about your ride experience…',
                              hintStyle: const TextStyle(
                                  fontSize: 13, color: Color(0xFFD1D5DB)),
                              contentPadding: const EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD97706)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Submit button ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Feedback'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(double r) {
    if (r >= 5) return 'Excellent!';
    if (r >= 4) return 'Good';
    if (r >= 3) return 'Average';
    if (r >= 2) return 'Poor';
    return 'Very poor';
  }
}
