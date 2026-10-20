class GroceryMessage {
  const GroceryMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.sentAt,
    this.items,
    this.itemImageUrl,
    this.billAmount,
    this.billNote,
    this.billImageUrl,
    this.imageUrl,
    this.paymentMethod,
    this.slipImageUrl,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String type;
  final String content;
  final String sentAt;
  final List<Map<String, dynamic>>? items;
  final String? itemImageUrl;
  final double? billAmount;
  final String? billNote;
  final String? billImageUrl;
  final String? imageUrl;
  final String? paymentMethod;
  final String? slipImageUrl;

  bool get isBill             => type == 'bill';
  bool get isItemList         => type == 'item_list';
  bool get isText             => type == 'text';
  bool get isImage            => type == 'image';
  bool get isPaymentIntent    => type == 'payment_intent';
  bool get isPaymentSlip      => type == 'payment_slip';
  bool get isPaymentConfirmed => type == 'payment_confirmed';
  bool get isDeliveryConfirmed => type == 'delivery_confirmed';
  bool get isReceiptConfirmed => type == 'receipt_confirmed';

  factory GroceryMessage.fromJson(Map<String, dynamic> json) {
    double? bill;
    if (json['bill_amount'] != null) {
      bill = (json['bill_amount'] as num).toDouble();
    }
    List<Map<String, dynamic>>? itemList;
    if (json['items'] != null) {
      itemList = (json['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return GroceryMessage(
      id:            json['id'] as String? ?? '',
      senderId:      json['sender_id'] as String? ?? '',
      senderName:    json['sender_name'] as String? ?? 'Student',
      type:          json['type'] as String? ?? 'text',
      content:       json['content'] as String? ?? '',
      sentAt:        json['sent_at'] as String? ?? '',
      items:         itemList,
      itemImageUrl:  json['item_image_url'] as String?,
      billAmount:    bill,
      billNote:      json['bill_note'] as String?,
      billImageUrl:  json['bill_image_url'] as String?,
      imageUrl:      json['image_url'] as String?,
      paymentMethod: json['payment_method'] as String?,
      slipImageUrl:  json['slip_image_url'] as String?,
    );
  }

  factory GroceryMessage.fromFirestore(Map<String, dynamic> data, String docId) {
    double? bill;
    if (data['bill_amount'] != null) {
      bill = (data['bill_amount'] as num).toDouble();
    }
    List<Map<String, dynamic>>? itemList;
    if (data['items'] != null) {
      itemList = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    String sentAt = '';
    final raw = data['sent_at'];
    if (raw != null) {
      try {
        sentAt = (raw as dynamic).toDate().toIso8601String();
      } catch (_) {
        sentAt = raw.toString();
      }
    }
    return GroceryMessage(
      id:            data['id'] as String? ?? docId,
      senderId:      data['sender_id'] as String? ?? '',
      senderName:    data['sender_name'] as String? ?? 'Student',
      type:          data['type'] as String? ?? 'text',
      content:       data['content'] as String? ?? '',
      sentAt:        sentAt,
      items:         itemList,
      itemImageUrl:  data['item_image_url'] as String?,
      billAmount:    bill,
      billNote:      data['bill_note'] as String?,
      billImageUrl:  data['bill_image_url'] as String?,
      imageUrl:      data['image_url'] as String?,
      paymentMethod: data['payment_method'] as String?,
      slipImageUrl:  data['slip_image_url'] as String?,
    );
  }
}
