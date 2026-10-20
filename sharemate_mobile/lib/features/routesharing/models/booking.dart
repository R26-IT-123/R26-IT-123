class Booking {
  const Booking({
    required this.id,
    required this.passengerId,
    required this.routeId,
    required this.driverId,
    required this.bookingType,
    required this.daysSelected,
    required this.fareAmount,
    required this.status,
    this.holdExpiresAt,
    this.priority = false,
    this.seatNumber,
    this.adjustedFare,
    this.pickupDistanceKm,
    this.createdAt,
    this.passengerYear,
  });

  final String id;
  final String passengerId;
  final String routeId;
  final String driverId;
  final String bookingType; // weekly / daily
  final List<String> daysSelected;
  final double fareAmount;
  final String status;
  final DateTime? holdExpiresAt;
  final bool priority;
  final int? seatNumber;
  final double? adjustedFare;
  final double? pickupDistanceKm;
  final DateTime? createdAt;
  final int? passengerYear;

  bool get isWeekly => bookingType == 'weekly';
  bool get isConfirmed => status == 'confirmed';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isBookingApproved => status == 'booking_approved';
  bool get isPaymentUploaded => status == 'payment_uploaded';
  bool get isPendingPayment => isBookingApproved;

  factory Booking.fromJson(Map<String, dynamic> json) {
    DateTime? holdExp;
    final holdStr = json['hold_expires_at'];
    if (holdStr is String) holdExp = DateTime.tryParse(holdStr);

    return Booking(
      id: json['id'] as String? ?? '',
      passengerId: json['passenger_id'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      bookingType: json['booking_type'] as String? ?? 'daily',
      daysSelected: List<String>.from(json['days_selected'] as List? ?? []),
      fareAmount: (json['fare_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending_approval',
      holdExpiresAt: holdExp,
      priority: json['priority'] as bool? ?? false,
      seatNumber: (json['seat_number'] as num?)?.toInt(),
      adjustedFare: (json['adjusted_fare'] as num?)?.toDouble(),
      pickupDistanceKm: (json['pickup_distance_km'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      passengerYear: (json['passenger_year'] as num?)?.toInt(),
    );
  }
}

class FareBreakdown {
  const FareBreakdown({
    required this.pricePerTrip,
    required this.daysCount,
    required this.bookingType,
    required this.discountPct,
    required this.discountAmount,
    required this.totalFare,
    required this.paymentType,
    this.routeDistanceKm,
    this.pickupDistanceKm,
    this.pricePerKm,
    this.friendSeatSubtotal,
    this.combinedTotal,
    this.pickmeEquivalent,
    this.savingVsPickme,
    this.passengerBoardingLabel,
    this.friendBoardingLabel,
    this.friendPricePerTrip,
  });

  final double? routeDistanceKm;
  final double? pickupDistanceKm;
  final double pricePerTrip;
  final double? pricePerKm;
  final int daysCount;
  final String bookingType;
  final double discountPct;
  final double discountAmount;
  final double totalFare;
  final String paymentType; // upfront / post-ride
  final double? friendSeatSubtotal;
  final double? combinedTotal;
  final double? pickmeEquivalent;
  final double? savingVsPickme;
  final String? passengerBoardingLabel;
  final String? friendBoardingLabel;
  final double? friendPricePerTrip;

  bool get isUpfront => paymentType == 'upfront';
  bool get hasDiscount => discountPct > 0;

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    return FareBreakdown(
      routeDistanceKm: (json['route_distance_km'] as num?)?.toDouble(),
      pickupDistanceKm: (json['pickup_distance_km'] as num?)?.toDouble(),
      pricePerTrip: (json['price_per_trip'] as num?)?.toDouble() ?? 0,
      pricePerKm: (json['price_per_km'] as num?)?.toDouble(),
      daysCount: (json['days_count'] as num?)?.toInt() ?? 0,
      bookingType: json['booking_type'] as String? ?? 'daily',
      discountPct: (json['discount_pct'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalFare: (json['total_fare'] as num?)?.toDouble() ?? 0,
      paymentType: json['payment_type'] as String? ?? 'post-ride',
      friendSeatSubtotal: (json['friend_seat_subtotal'] as num?)?.toDouble(),
      combinedTotal: (json['combined_total'] as num?)?.toDouble(),
      pickmeEquivalent: (json['pickme_equivalent'] as num?)?.toDouble(),
      savingVsPickme: (json['saving_vs_pickme'] as num?)?.toDouble(),
    );
  }
}

class PaymentSlip {
  const PaymentSlip({
    required this.id,
    required this.bookingId,
    required this.slipImageUrl,
    required this.reviewStatus,
    this.rejectionReason,
    this.submittedAt,
  });

  final String id;
  final String bookingId;
  final String slipImageUrl;
  final String reviewStatus; // pending / approved / rejected
  final String? rejectionReason;
  final DateTime? submittedAt;

  factory PaymentSlip.fromJson(Map<String, dynamic> json) {
    DateTime? sub;
    final subStr = json['submitted_at'];
    if (subStr is String) sub = DateTime.tryParse(subStr);
    return PaymentSlip(
      id: json['id'] as String? ?? '',
      bookingId: json['booking_id'] as String? ?? '',
      slipImageUrl: json['slip_image_url'] as String? ?? '',
      reviewStatus: json['review_status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: sub,
    );
  }
}
