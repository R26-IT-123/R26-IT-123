import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/item_request.dart';
import '../services/grocery_api_service.dart';
import 'grocery_chat_screen.dart';

class BrowseItemRequestsScreen extends StatefulWidget {
  const BrowseItemRequestsScreen({super.key});

  @override
  State<BrowseItemRequestsScreen> createState() =>
      _BrowseItemRequestsScreenState();
}

class _BrowseItemRequestsScreenState
    extends State<BrowseItemRequestsScreen> {
  final _service = GroceryApiService();
  final _myUid   = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<GroceryItemRequest> _requests = [];
  bool    _loading    = true;
  String? _error;
  String? _contactingRequestId;

  static const _accent  = Color(0xFF0369A1);
  static const _bgLight = Color(0xFFE0F2FE);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.fetchItemRequests();
      if (mounted) setState(() => _requests = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _contact(GroceryItemRequest req) async {
    if (_contactingRequestId != null) return;
    setState(() => _contactingRequestId = req.id);
    try {
      final result = await _service.contactRequester(req.id);
      final chatId = result['chat_id'] as String;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroceryChatScreen(
            chatId:          chatId,
            otherPersonName: req.requesterName,
            supermarket:     req.supermarket,
            isShopper:       true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final alreadyTaken = msg.toLowerCase().contains('no longer open');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyTaken
              ? 'Someone else already offered to help — request is taken.'
              : msg),
          backgroundColor:
              alreadyTaken ? const Color(0xFF374151) : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (alreadyTaken) _load(); // refresh so the taken card disappears
    } finally {
      if (mounted) setState(() => _contactingRequestId = null);
    }
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
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
                        'Item Requests',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'People who need items — tap to offer help',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded,
                        color: _accent, size: 22),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    size: 48, color: Color(0xFFD1D5DB)),
                                const SizedBox(height: 16),
                                const Text('Could not load requests',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: _accent),
                                  onPressed: _load,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _requests.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: const BoxDecoration(
                                          color: _bgLight,
                                          shape: BoxShape.circle),
                                      child: const Icon(
                                          Icons.shopping_basket_outlined,
                                          color: _accent,
                                          size: 36),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No open requests right now',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'When someone posts items they need, they will appear here. Check back soon!',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF9CA3AF),
                                          height: 1.4),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: _accent,
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: _requests.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final req = _requests[i];
                                  final isOwn = req.requesterId == _myUid;
                                  return _ItemRequestCard(
                                    request:    req,
                                    isOwn:      isOwn,
                                    timeAgo:    _timeAgo(req.createdAt),
                                    contacting: _contactingRequestId == req.id,
                                    onContact:  isOwn
                                        ? null
                                        : () => _contact(req),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRequestCard extends StatelessWidget {
  const _ItemRequestCard({
    required this.request,
    required this.isOwn,
    required this.timeAgo,
    required this.contacting,
    required this.onContact,
  });

  final GroceryItemRequest request;
  final bool               isOwn;
  final String             timeAgo;
  final bool               contacting;
  final VoidCallback?      onContact;

  static const _accent  = Color(0xFF0369A1);
  static const _bgLight = Color(0xFFE0F2FE);

  @override
  Widget build(BuildContext context) {
    final initials = request.requesterName.isNotEmpty
        ? request.requesterName[0].toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isOwn
            ? Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isOwn ? _accent : _bgLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isOwn ? Colors.white : _accent,
                      )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOwn ? 'You' : request.requesterName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827)),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _bgLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('You',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _accent)),
                          ),
                        ],
                      ],
                    ),
                    Text(timeAgo,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              // Supermarket badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(request.supermarket,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Item chips ─────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: request.items.map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(item['name'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _accent)),
              );
            }).toList(),
          ),

          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(request.note,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.3)),
          ],

          const SizedBox(height: 14),

          // ── Action ─────────────────────────────────────────
          if (isOwn)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: _accent),
                  SizedBox(width: 6),
                  Text('This is your request',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accent)),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: contacting ? null : onContact,
                icon: contacting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.handshake_rounded, size: 16),
                label: const Text('I Can Help'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
