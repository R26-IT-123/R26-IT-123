import 'package:flutter/material.dart';

import '../services/grocery_api_service.dart';
import 'my_item_requests_screen.dart';

class PostItemRequestScreen extends StatefulWidget {
  const PostItemRequestScreen({super.key});

  @override
  State<PostItemRequestScreen> createState() => _PostItemRequestScreenState();
}

class _PostItemRequestScreenState extends State<PostItemRequestScreen> {
  final _service       = GroceryApiService();
  final _marketCtrl    = TextEditingController();
  final _itemCtrl      = TextEditingController();
  final _noteCtrl      = TextEditingController();
  final _items         = <Map<String, dynamic>>[];
  bool  _submitting    = false;

  static const _accent  = Color(0xFF0369A1);
  static const _bgLight = Color(0xFFE0F2FE);

  @override
  void dispose() {
    _marketCtrl.dispose();
    _itemCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final v = _itemCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _items.add({'name': v});
      _itemCtrl.clear();
    });
  }

  Future<void> _submit() async {
    final market = _marketCtrl.text.trim();
    if (market.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a supermarket name.')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.postItemRequest(
        supermarket: market,
        items: List.from(_items),
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your item request is live! Shoppers can now see it.'),
          backgroundColor: Color(0xFF0369A1),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const MyItemRequestsScreen(),
        ),
      );
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post My Needs',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Shoppers will see your list and offer to help',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyItemRequestsScreen(),
                      ),
                    ),
                    child: const Text('My Requests',
                        style: TextStyle(color: _accent, fontSize: 13)),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: _accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your request stays live for 24 hours. Any shopper heading to your chosen supermarket can contact you.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _accent.withValues(alpha: 0.9),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _Label('Supermarket'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _marketCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco('e.g. Keells, Food City, Cargills'),
                    ),

                    const SizedBox(height: 20),

                    _Label('Items I Need'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _inputDeco('e.g. 1kg Sugar'),
                            onSubmitted: (_) => _addItem(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                          onPressed: _addItem,
                          child: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ],
                    ),

                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: _items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: _accent, size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(item['name'] as String,
                                            style: const TextStyle(fontSize: 14)),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _items.remove(item)),
                                        child: const Icon(Icons.close_rounded,
                                            size: 16,
                                            color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    _Label('Note (optional)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco(
                          'Any extra info for the shopper, e.g. brand preferences…'),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Post My Item Request',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
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

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      );
}
