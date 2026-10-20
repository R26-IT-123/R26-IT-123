class RideSession {
  const RideSession({
    required this.id,
    required this.routeId,
    required this.driverId,
    required this.rideDate,
    required this.status,
    required this.passengerIds,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String routeId;
  final String driverId;
  final String rideDate;
  final String status; // active / completed / cancelled
  final List<String> passengerIds;
  final DateTime? startTime;
  final DateTime? endTime;

  bool get isActive => status == 'active';

  factory RideSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;
    return RideSession(
      id: json['id'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      rideDate: json['ride_date'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      passengerIds:
          List<String>.from(json['passenger_ids'] as List? ?? []),
      startTime: parseDate(json['start_time']),
      endTime: parseDate(json['end_time']),
    );
  }
}

class PassengerRideInfo {
  const PassengerRideInfo({
    required this.passengerId,
    required this.fareAmount,
    required this.bookingType,
    required this.paymentStatus,
    this.bookingId,
    this.seatNumber,
    this.passengerName,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.pickupDistanceFromStartKm,
  });

  final String passengerId;
  final String? bookingId;
  final int? seatNumber;
  final String? passengerName;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;
  final double? pickupDistanceFromStartKm;
  final double fareAmount;
  final String bookingType;
  final String paymentStatus; // pending / paid

  double get fareForToday => fareAmount;
  bool get paidToday => paymentStatus == 'paid';

  factory PassengerRideInfo.fromJson(Map<String, dynamic> json) {
    return PassengerRideInfo(
      passengerId: json['passenger_id'] as String? ?? '',
      bookingId: json['booking_id'] as String?,
      seatNumber: (json['seat_number'] as num?)?.toInt(),
      passengerName: json['passenger_name'] as String?,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      pickupAddress: json['pickup_address'] as String?,
      pickupDistanceFromStartKm:
          (json['pickup_distance_from_start_km'] as num?)?.toDouble(),
      fareAmount: (json['fare_amount'] as num?)?.toDouble() ?? 0,
      bookingType: json['booking_type'] as String? ?? 'daily',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
    );
  }
}

class RideFeedback {
  const RideFeedback({
    required this.rideSessionId,
    required this.driverId,
    required this.overallRating,
    required this.comment,
  });

  final String rideSessionId;
  final String driverId;
  final double overallRating;
  final String comment;

  Map<String, dynamic> toJson() => {
        'ride_session_id': rideSessionId,
        'driver_id': driverId,
        'overall_rating': overallRating,
        'comment': comment,
      };
}
