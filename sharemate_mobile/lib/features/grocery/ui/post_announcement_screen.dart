import 'package:flutter/material.dart';

import '../services/grocery_api_service.dart';
import 'announcements_screen.dart';

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({super.key});

  @override
  State<PostAnnouncementScreen> createState() => _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  final _service = GroceryApiService();
  final _supermarketCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _accent = Color(0xFFBE185D);
  static const _bgLight = Color(0xFFFCE7F3);

  static const _supermarkets = [
    'Food City',
    'Keells',
    'Cargills',
    'Arpico',
    'Laugfs',
    'Spar',
  ];

  @override
  void dispose() {
    _supermarketCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final supermarket = _supermarketCtrl.text.trim();
    if (supermarket.isEmpty) {
      setState(() => _error = 'Please select or enter a supermarket name.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.postAnnouncement(
        supermarket: supermarket,
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      // Replace with announcements screen in shopper mode
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AnnouncementsScreen(mode: AnnouncementsMode.shopper),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Going to Market',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Let peers know you\'re at a supermarket',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Info card ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: _accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your announcement will be visible to all SLIIT students for 3 hours.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.pink.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Supermarket ──────────────────────────────
                    const Text(
                      'Which supermarket?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick-select chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _supermarkets
                          .map((s) => _SupermarketChip(
                                label: s,
                                selected: _supermarketCtrl.text == s,
                                onTap: () => setState(
                                    () => _supermarketCtrl.text = s),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: 14),

                    // Manual entry
                    TextField(
                      controller: _supermarketCtrl,
                      decoration: InputDecoration(
                        hintText: 'Or type a supermarket name',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        prefixIcon: const Icon(Icons.storefront_rounded,
                            color: _accent, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 24),

                    // ── Message ──────────────────────────────────
                    const Text(
                      'Message (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageCtrl,
                      maxLines: 3,
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Going now, back in about an hour. Happy to help!',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Submit ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Post Announcement',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupermarketChip extends StatelessWidget {
  const _SupermarketChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBE185D);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
