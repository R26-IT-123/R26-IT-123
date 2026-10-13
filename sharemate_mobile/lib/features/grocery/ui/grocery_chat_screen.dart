import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/message.dart';
import '../models/trust_profile.dart';
import '../services/grocery_api_service.dart';
import 'feedback_sheet.dart';
import 'trust_profile_screen.dart';

class GroceryChatScreen extends StatefulWidget {
  const GroceryChatScreen({
    super.key,
    required this.chatId,
    this.otherPersonName,
    this.supermarket,
    this.isShopper,
  });

  final String chatId;
  final String? otherPersonName;
  final String? supermarket;
  final bool? isShopper;

  @override
  State<GroceryChatScreen> createState() => _GroceryChatScreenState();
}

class _GroceryChatScreenState extends State<GroceryChatScreen> {
  final _service    = GroceryApiService();
  final _myUid      = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool    _sending           = false;
  String? _otherName;
  String? _otherUid;
  String? _supermarket;
  bool    _isShopper         = false;
  String? _paymentStatus;
  bool    _feedbackSubmitted = false;
  TrustProfile? _otherTrust;

  StreamSubscription<DocumentSnapshot>? _chatSub;

  static const _accent   = Color(0xFFBE185D);
  static const _bgLight  = Color(0xFFFCE7F3);
  static const _green    = Color(0xFF059669);
  static const _blue     = Color(0xFF0369A1);

  @override
  void initState() {
    super.initState();
    _otherName   = widget.otherPersonName;
    _supermarket = widget.supermarket;
    _isShopper   = widget.isShopper ?? false;
    if (widget.isShopper == null || _otherName == null || _supermarket == null) {
      _loadChatMeta();
    }
    _listenChatStatus();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _listenChatStatus() {
    _chatSub = FirebaseFirestore.instance
        .collection('grocery_chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data()!;
      final newStatus = data['payment_status'] as String?;
      setState(() => _paymentStatus = newStatus);
      if (newStatus == 'completed') _checkFeedbackStatus();
    });
  }

  Future<void> _loadChatMeta() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('grocery_chats')
          .doc(widget.chatId)
          .get();
      if (!mounted || !doc.exists) return;
      final data = doc.data()!;
      final shopperId    = data['shopper_id']    as String? ?? '';
      final requesterId  = data['requester_id']  as String? ?? '';
      final isShopper    = _myUid == shopperId;
      setState(() {
        _isShopper   = isShopper;
        _otherUid    = isShopper ? requesterId : shopperId;
        _otherName   = isShopper
            ? data['requester_name'] as String? ?? 'Requester'
            : data['shopper_name']   as String? ?? 'Shopper';
        _supermarket = data['supermarket'] as String? ?? '';
      });
      _loadOtherTrust();
    } catch (_) {}
  }

  Future<void> _loadOtherTrust() async {
    final uid = _otherUid;
    if (uid == null || uid.isEmpty) return;
    try {
      final profile = await _service.getTrustProfile(uid);
      if (mounted) setState(() => _otherTrust = profile);
    } catch (_) {}
  }

  Future<void> _checkFeedbackStatus() async {
    try {
      final submitted = await _service.hasSubmittedFeedback(widget.chatId);
      if (mounted) setState(() => _feedbackSubmitted = submitted);
    } catch (_) {}
  }

  Future<void> _showFeedbackSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FeedbackSheet(
        chatId: widget.chatId,
        otherPersonName: _otherName ?? 'this person',
        service: _service,
      ),
    );
    if (submitted == true && mounted) {
      setState(() => _feedbackSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted. Thank you!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
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

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await _service.sendTextMessage(chatId: widget.chatId, content: text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showItemListDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ItemListSheet(chatId: widget.chatId, service: _service),
    );
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSourceBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImage(ImageSource source) async {
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (xf == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final uid = _myUid.isNotEmpty ? _myUid : 'anon';
      final ref = FirebaseStorage.instance.ref().child(
          'grocery_images/${widget.chatId}/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(xf.path));
      final url = await ref.getDownloadURL();
      await _service.sendImageMessage(chatId: widget.chatId, imageUrl: url);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showBillDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _BillSheet(chatId: widget.chatId, service: _service),
    );
  }

  Future<void> _showPaymentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PaymentSheet(chatId: widget.chatId, service: _service),
    );
  }

  Future<void> _confirmPayment() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _service.confirmPayment(chatId: widget.chatId);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markDelivered() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _service.markDelivered(chatId: widget.chatId);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmReceipt() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _service.confirmReceipt(chatId: widget.chatId);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(GroceryMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete message',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('This message will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteMessage(chatId: widget.chatId, messageId: msg.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  // ── Action bar ──────────────────────────────────────────────────────────────

  Widget? _buildActionBar() {
    String? label;
    String? btnLabel;
    IconData? btnIcon;
    Color? color;
    VoidCallback? action;

    if (_paymentStatus == 'cash_pending' && _isShopper) {
      label    = 'Cash payment chosen. Deliver the items.';
      btnLabel = 'Mark as Delivered';
      btnIcon  = Icons.local_shipping_rounded;
      color    = _green;
      action   = _markDelivered;
    } else if (_paymentStatus == 'slip_uploaded' && _isShopper) {
      label    = 'Check the payment slip and confirm.';
      btnLabel = 'Confirm Payment';
      btnIcon  = Icons.check_circle_rounded;
      color    = _blue;
      action   = _confirmPayment;
    } else if (_paymentStatus == 'payment_confirmed' && _isShopper) {
      label    = 'Payment confirmed. Deliver the items.';
      btnLabel = 'Mark as Delivered';
      btnIcon  = Icons.local_shipping_rounded;
      color    = _green;
      action   = _markDelivered;
    } else if (_paymentStatus == 'delivered' && !_isShopper) {
      label    = 'Your items have been delivered!';
      btnLabel = 'Confirm Receipt';
      btnIcon  = Icons.done_all_rounded;
      color    = _accent;
      action   = _confirmReceipt;
    } else if (_paymentStatus == 'completed') {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: _green, size: 16),
                SizedBox(width: 8),
                Text(
                  'Transaction complete',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _green),
                ),
              ],
            ),
            if (!_feedbackSubmitted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showFeedbackSheet,
                  icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                  label: const Text(
                    'Rate your experience',
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                  SizedBox(width: 4),
                  Text(
                    'Feedback submitted',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    if (label == null) return null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _sending ? null : action,
            icon: _sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(btnIcon!, size: 16),
            label: Text(btnLabel!),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: _bgLight, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _otherUid != null && _otherUid!.isNotEmpty
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TrustProfileScreen(
                                    uid: _otherUid!,
                                    displayName: _otherName ?? 'User',
                                  ),
                                ),
                              )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _otherName ?? '...',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (_otherTrust != null && _otherTrust!.totalRatings > 0)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(
                                  '${_otherTrust!.avgRating.toStringAsFixed(1)}  •  ${_otherTrust!.totalRatings} ${_otherTrust!.totalRatings == 1 ? 'rating' : 'ratings'}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                              ],
                            )
                          else if (_supermarket != null && _supermarket!.isNotEmpty)
                            Text(
                              _supermarket!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Messages ─────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('grocery_chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('sent_at')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _accent));
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
                              'Chat is open',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isShopper
                                  ? 'The item list will appear here shortly.'
                                  : 'Send your item list or start with a message.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
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
                      final msg = GroceryMessage.fromFirestore(
                        docs[i].data() as Map<String, dynamic>,
                        docs[i].id,
                      );
                      final isMine = msg.senderId == _myUid;
                      return _MessageBubble(
                        message:       msg,
                        isMine:        isMine,
                        isShopper:     _isShopper,
                        paymentStatus: _paymentStatus,
                        onPayNow:      _showPaymentSheet,
                        onDelete:      isMine ? () => _deleteMessage(msg) : null,
                      );
                    },
                  );
                },
              ),
            ),

            // ── Action bar (payment flow) ─────────────────────────────────
            Builder(builder: (_) {
              final bar = _buildActionBar();
              if (bar == null) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  bar,
                ],
              );
            }),

            // ── Input bar ─────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  _InputIconBtn(
                    icon: Icons.list_rounded,
                    tooltip: 'Send item list',
                    onTap: _showItemListDialog,
                  ),
                  const SizedBox(width: 6),
                  _InputIconBtn(
                    icon: Icons.camera_alt_rounded,
                    tooltip: 'Send image',
                    onTap: _showImageSourceSheet,
                  ),
                  if (_isShopper) ...[
                    const SizedBox(width: 6),
                    _InputIconBtn(
                      icon: Icons.receipt_rounded,
                      tooltip: 'Add bill',
                      onTap: _showBillDialog,
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendText,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

// ─────────────────────────────────────────────────────────────────────────────
// Item List Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ItemListSheet extends StatefulWidget {
  const _ItemListSheet({required this.chatId, required this.service});
  final String chatId;
  final GroceryApiService service;

  @override
  State<_ItemListSheet> createState() => _ItemListSheetState();
}

class _ItemListSheetState extends State<_ItemListSheet> {
  final _itemCtrl = TextEditingController();
  final _items    = <Map<String, dynamic>>[];
  File? _pickedImage;
  bool  _sending = false;

  static const _accent = Color(0xFFBE185D);

  @override
  void dispose() {
    _itemCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 75);
    if (xf != null && mounted) setState(() => _pickedImage = File(xf.path));
  }

  Future<void> _send() async {
    if (_items.isEmpty || _sending) return;
    setState(() => _sending = true);

    String? imageUrl;
    if (_pickedImage != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
        final ref = FirebaseStorage.instance.ref().child(
            'grocery_items/${widget.chatId}/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_pickedImage!);
        imageUrl = await ref.getDownloadURL();
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pop(context);

    try {
      await widget.service.sendItemList(
        chatId: widget.chatId,
        items: List.from(_items),
        imageUrl: imageUrl,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send Item List',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add an item (e.g. 1kg Sugar)',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                onPressed: () {
                  final v = _itemCtrl.text.trim();
                  if (v.isEmpty) return;
                  setState(() {
                    _items.add({'name': v});
                    _itemCtrl.clear();
                  });
                },
                child: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 14),
            ..._items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: _accent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item['name'] as String,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _items.remove(item)),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 20),
          const Text('Reference photo (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          const SizedBox(height: 10),
          if (_pickedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_pickedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _pickedImage = null),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 4),
                  Text('Remove photo', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _ImageSourceBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSourceBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (_items.isEmpty || _sending) ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send List',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bill Sheet (shopper only)
// ─────────────────────────────────────────────────────────────────────────────

class _BillSheet extends StatefulWidget {
  const _BillSheet({required this.chatId, required this.service});
  final String chatId;
  final GroceryApiService service;

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  File? _pickedImage;
  bool  _sending = false;

  static const _accent = Color(0xFFBE185D);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 75);
    if (xf != null && mounted) setState(() => _pickedImage = File(xf.path));
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }
    setState(() => _sending = true);

    String? imageUrl;
    if (_pickedImage != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
        final ref = FirebaseStorage.instance.ref().child(
            'grocery_bills/${widget.chatId}/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_pickedImage!);
        imageUrl = await ref.getDownloadURL();
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pop(context);

    try {
      await widget.service.sendBill(
        chatId: widget.chatId,
        amount: amount,
        note: _noteCtrl.text.trim(),
        imageUrl: imageUrl,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Bill',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Total amount (LKR)',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixText: 'LKR ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: _accent),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Bill photo (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          const SizedBox(height: 10),
          if (_pickedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_pickedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _pickedImage = null),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 4),
                  Text('Remove photo', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _ImageSourceBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSourceBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Bill',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Sheet (requester — cash or online)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.chatId, required this.service});
  final String chatId;
  final GroceryApiService service;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String? _selected; // 'cash' | 'online'
  File?   _slipImage;
  bool    _sending = false;

  static const _green = Color(0xFF059669);
  static const _blue  = Color(0xFF0369A1);
  static const _accent = Color(0xFFBE185D);

  Future<void> _pickSlip(ImageSource source) async {
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (xf != null && mounted) setState(() => _slipImage = File(xf.path));
  }

  Future<void> _submit() async {
    if (_selected == null || _sending) return;
    setState(() => _sending = true);

    if (_selected == 'cash') {
      Navigator.pop(context);
      try {
        await widget.service.sendPaymentIntent(chatId: widget.chatId, method: 'cash');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Online — upload slip first
    if (_slipImage == null) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your payment slip.')),
      );
      return;
    }

    String slipUrl;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final ref = FirebaseStorage.instance.ref().child(
          'grocery_payments/${widget.chatId}/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_slipImage!);
      slipUrl = await ref.getDownloadURL();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    try {
      await widget.service.sendPaymentSlip(chatId: widget.chatId, slipImageUrl: slipUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final btnColor = _selected == 'online' ? _blue : (_selected == 'cash' ? _green : _accent);
    final btnLabel = _selected == 'cash' ? 'Confirm Cash Payment' : 'Upload Slip & Confirm';
    final canSubmit = _selected != null && !_sending &&
        !(_selected == 'online' && _slipImage == null);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pay for Items',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Choose how you will pay the shopper',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 20),

          // ── Cash option ─────────────────────────────────────────────
          _PaymentOptionCard(
            icon: Icons.handshake_rounded,
            title: 'Cash in Hand',
            subtitle: 'Pay the shopper in cash when they deliver your items.',
            selected: _selected == 'cash',
            color: _green,
            onTap: () => setState(() { _selected = 'cash'; _slipImage = null; }),
          ),
          const SizedBox(height: 12),

          // ── Online option ───────────────────────────────────────────
          _PaymentOptionCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Online Transfer',
            subtitle: 'Transfer money and upload your payment slip as proof.',
            selected: _selected == 'online',
            color: _blue,
            onTap: () => setState(() => _selected = 'online'),
          ),

          // ── Slip picker (online only) ───────────────────────────────
          if (_selected == 'online') ...[
            const SizedBox(height: 20),
            const Text('Upload Payment Slip',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 10),
            if (_slipImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(_slipImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _slipImage = null),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 4),
                    Text('Remove', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceBtn(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => _pickSlip(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceBtn(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => _pickSlip(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: btnColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: canSubmit ? _submit : null,
              child: _sending
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(btnLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData  icon;
  final String    title;
  final String    subtitle;
  final bool      selected;
  final Color     color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: selected ? color : const Color(0xFF9CA3AF), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : const Color(0xFF111827),
                      )),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280), height: 1.3)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isShopper,
    required this.paymentStatus,
    required this.onPayNow,
    this.onDelete,
  });

  final GroceryMessage message;
  final bool           isMine;
  final bool           isShopper;
  final String?        paymentStatus;
  final VoidCallback   onPayNow;
  final VoidCallback?  onDelete;

  static const _accent = Color(0xFFBE185D);
  static const _green  = Color(0xFF059669);
  static const _blue   = Color(0xFF0369A1);

  @override
  Widget build(BuildContext context) {
    if (message.isBill)             return _buildBillBubble();
    if (message.isItemList)         return _buildItemListBubble();
    if (message.isImage)            return _buildImageBubble();
    if (message.isPaymentIntent)    return _buildPaymentIntentBubble();
    if (message.isPaymentSlip)      return _buildPaymentSlipBubble();
    if (message.isPaymentConfirmed) {
      return _buildSystemBubble(
        icon: Icons.check_circle_rounded,
        text: isMine ? 'You confirmed the payment' : '${message.senderName} confirmed the payment',
        color: _green,
      );
    }
    if (message.isDeliveryConfirmed) {
      return _buildSystemBubble(
        icon: Icons.local_shipping_rounded,
        text: isMine ? 'You marked items as delivered' : 'Items have been delivered',
        color: const Color(0xFF7C3AED),
      );
    }
    if (message.isReceiptConfirmed) {
      return _buildSystemBubble(
        icon: Icons.done_all_rounded,
        text: 'Transaction complete',
        color: _green,
      );
    }
    return _buildTextBubble();
  }

  Widget _buildTextBubble() {
    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? _accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accent.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(
              message.content,
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
    if (onDelete == null) return bubble;
    return GestureDetector(onLongPress: onDelete, child: bubble);
  }

  Widget _buildItemListBubble() {
    final items    = message.items ?? [];
    final imageUrl = message.itemImageUrl;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.list_rounded, color: _accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${isMine ? 'Your' : '${message.senderName}\'s'} Item List',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _accent),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item['name'] as String? ?? '',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                          ),
                        ]),
                      )),
                  if (items.isEmpty)
                    const Text('Empty list',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBubble() {
    final url = message.imageUrl ?? '';
    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: url.isNotEmpty
              ? Image.network(url, fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180, width: 260, color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 80, width: 260, color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.broken_image_rounded,
                        color: Color(0xFFD1D5DB), size: 32),
                  ))
              : const SizedBox.shrink(),
        ),
      ),
    );
    if (onDelete == null) return bubble;
    return GestureDetector(onLongPress: onDelete, child: bubble);
  }

  Widget _buildBillBubble() {
    final amount   = message.billAmount ?? 0;
    final note     = message.billNote ?? '';
    final imageUrl = message.billImageUrl;

    // "Pay Now" is shown on the bill bubble for the requester when payment hasn't started
    final showPayNow = !isMine && !isShopper && paymentStatus == null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9D174D), Color(0xFFBE185D)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                child: Image.network(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMine ? 'Bill Added' : '${message.senderName} added a bill',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'LKR ${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.3,
                        )),
                  ],
                ],
              ),
            ),

            // Pay Now button — requester only, payment not yet started
            if (showPayNow)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onPayNow,
                    icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                    label: const Text('Pay Now',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentIntentBubble() {
    return _buildSystemBubble(
      icon: Icons.handshake_rounded,
      text: isMine
          ? 'You will pay cash on delivery'
          : '${message.senderName} will pay cash on delivery',
      color: _green,
    );
  }

  Widget _buildPaymentSlipBubble() {
    final slipUrl = message.slipImageUrl ?? '';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _blue.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (slipUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                child: Image.network(slipUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded, color: _blue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isMine ? 'Your Payment Slip' : '${message.senderName}\'s Payment Slip',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _blue),
                  ),
                ),
                if (isMine && paymentStatus == 'slip_uploaded')
                  const Text('Waiting...',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBubble({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(text,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Icon Button
// ─────────────────────────────────────────────────────────────────────────────

class _InputIconBtn extends StatelessWidget {
  const _InputIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData     icon;
  final String       tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFCE7F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFBE185D), size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Source Button (Camera / Gallery)
// ─────────────────────────────────────────────────────────────────────────────

class _ImageSourceBtn extends StatelessWidget {
  const _ImageSourceBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFBE185D), size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                )),
          ],
        ),
      ),
    );
  }
}
