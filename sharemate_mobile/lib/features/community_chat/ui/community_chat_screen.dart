import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/community_chat_api_service.dart';

/// A single, shared chat room every signed-in student can read and post to.
class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  static const _accent = Color(0xFF24AE59);

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _apiService = CommunityChatApiService();
  bool _sending = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Student';

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('community_chat').add({
        'sender_id': _myUid,
        'sender_name': _myName,
        'text': text,
        'sent_at': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
      // Push notification for other students — non-critical, message is
      // already stored above even if this fails.
      unawaited(
        _apiService
            .notifyNewMessage(senderName: _myName, text: text)
            .catchError((_) {}),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.forum_rounded,
                        color: _accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Chat',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Open to every SLIIT student',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Messages ───────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('community_chat')
                    .orderBy('sent_at')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: Color(0xFFD1D5DB)),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Say hello to the SLIIT community.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF9CA3AF)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final isMine = data['sender_id'] == _myUid;
                      return _ChatBubble(
                        senderName: data['sender_name'] as String? ?? 'Student',
                        text: data['text'] as String? ?? '',
                        isMine: isMine,
                      );
                    },
                  );
                },
              ),
            ),

            // ── Input bar ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Message the community...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: _accent, shape: BoxShape.circle),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.senderName,
    required this.text,
    required this.isMine,
  });

  final String senderName;
  final String text;
  final bool isMine;

  static const _accent = Color(0xFF24AE59);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? _accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accent.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : const Color(0xFF111827),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
