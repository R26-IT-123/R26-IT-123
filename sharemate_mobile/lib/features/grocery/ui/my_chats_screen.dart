import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../services/grocery_api_service.dart';
import 'grocery_chat_screen.dart';

class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  @override
  State<MyChatsScreen> createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen> {
  final _service = GroceryApiService();
  final _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<GroceryChat> _chats = [];
  bool _loading = true;
  String? _error;

  static const _accent = Color(0xFFBE185D);
  static const _bgLight = Color(0xFFFCE7F3);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _deleteChat(GroceryChat chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete chat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            'This chat will be closed and removed from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.closeChat(chat.id);
      if (mounted) setState(() => _chats.remove(chat));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await _service.fetchMyChats();
      if (mounted) setState(() => _chats = chats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ───────────────────────────────────────
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
                        'My Grocery Chats',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Your active shopper conversations',
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

            // ── Body ─────────────────────────────────────────
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
                                    size: 48,
                                    color: Color(0xFFD1D5DB)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Could not load chats',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
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
                      : _chats.isEmpty
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
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: _accent,
                                          size: 36),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No chats yet',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'When you request items from a shopper or someone requests from you, the chat will appear here.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9CA3AF),
                                        height: 1.4,
                                      ),
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
                                itemCount: _chats.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final chat = _chats[i];
                                  final otherName =
                                      chat.otherPersonName(_myUid);
                                  final role = chat.myRole(_myUid);
                                  final initials = otherName.isNotEmpty
                                      ? otherName[0].toUpperCase()
                                      : 'S';

                                  return GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => GroceryChatScreen(
                                          chatId: chat.id,
                                          otherPersonName: otherName,
                                          supermarket: chat.supermarket,
                                          isShopper: chat.myRole(_myUid) == 'shopper',
                                        ),
                                      ),
                                    ),
                                    onLongPress: () => _deleteChat(chat),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x06000000),
                                              blurRadius: 10,
                                              offset: Offset(0, 2)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: const BoxDecoration(
                                              color: _bgLight,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color: _accent,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        otherName,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                              0xFF111827),
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      _timeAgo(
                                                          chat.lastMessageAt ??
                                                              chat.createdAt),
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                              0xFF9CA3AF)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 7,
                                                              vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFF0FDF4),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        chat.supermarket,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                              0xFF16A34A),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 7,
                                                              vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: _bgLight,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        role == 'shopper'
                                                            ? 'Shopper'
                                                            : 'Requester',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: _accent,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (chat.lastMessage !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    chat.lastMessage!,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Color(0xFF6B7280),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons
                                                  .chevron_right_rounded,
                                              color: Color(0xFFD1D5DB),
                                              size: 20),
                                        ],
                                      ),
                                    ),
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
