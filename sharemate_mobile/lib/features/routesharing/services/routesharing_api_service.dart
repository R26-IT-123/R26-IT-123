import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../models/ride_session.dart';
import '../models/route_notification.dart';
import '../models/route_post.dart';

class RouteSharingApiService {
  RouteSharingApiService({ApiClient? apiClient, FirebaseAuth? auth})
      : _api = apiClient ?? ApiClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  static const _base = '/api/routesharing';

  Future<Map<String, String>> _authHeader() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No authenticated Firebase user.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  // ── Rate config ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchRates() async {
    final h = await _authHeader();
    return _api.getJson('$_base/rates', headers: h);
  }

  // ── Routes ──────────────────────────────────────────────────────────────────

  Future<List<RoutePost>> searchRoutes({String? destination}) async {
    final h = await _authHeader();
    var path = '$_base/routes';
    if (destination != null && destination.isNotEmpty) {
      path += '?destination=${Uri.encodeComponent(destination)}';
    }
    final list = await _api.getList(path, headers: h);
    return list.map((e) => RoutePost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RoutePost> getRoute(String routeId) async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/routes/$routeId', headers: h);
    return RoutePost.fromJson(json);
  }

  Future<RoutePost> publishRoute({
    required double startLat,
    required double startLng,
    String? startAddress,
    required String destination,
    double? destinationLat,
    double? destinationLng,
    required String startDate,
    required String departureTime,
    required int totalSeats,
    List<Map<String, dynamic>> waypoints = const [],
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/routes',
      headers: h,
      body: {
        'start_location': {
          'lat': startLat,
          'lng': startLng,
          if (startAddress != null) 'address': startAddress,
        },
        'destination': destination,
        if (destinationLat != null) 'destination_lat': destinationLat,
        if (destinationLng != null) 'destination_lng': destinationLng,
        'start_date': startDate,
        'departure_time': departureTime,
        'total_seats': totalSeats,
        'vehicle_type': 'car',
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
      },
    );
    return RoutePost.fromJson(json);
  }

  Future<List<RoutePost>> getDriverRoutes() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/driver/routes', headers: h);
    return list.map((e) => RoutePost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PricingSuggestion> getRoutePricing(String routeId) async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/routes/$routeId/pricing', headers: h);
    return PricingSuggestion.fromJson(json);
  }

  Future<void> deactivateRoute(String routeId) async {
    final h = await _authHeader();
    await _api.deleteJson('$_base/routes/$routeId', headers: h);
  }

  // ── Driver profile ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDriverProfile() async {
    final h = await _authHeader();
    return _api.getJson('$_base/driver/profile', headers: h);
  }

  Future<Map<String, dynamic>> updateDriverProfile(Map<String, dynamic> data) async {
    final h = await _authHeader();
    return _api.putJson('$_base/driver/profile', headers: h, body: data);
  }

  Future<Map<String, dynamic>> getDriverBankAccount(String driverId) async {
    final h = await _authHeader();
    return _api.getJson('$_base/driver/$driverId/bank-account', headers: h);
  }

  // ── Bookings ────────────────────────────────────────────────────────────────

  Future<Booking> createBooking({
    required String routeId,
    required String bookingType,
    required List<String> daysSelected,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    bool addFriendSeat = false,
    String? friendName,
    String? friendContact,
    double? friendPickupLat,
    double? friendPickupLng,
    String? friendPickupAddress,
  }) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings',
      headers: h,
      body: {
        'route_id': routeId,
        'booking_type': bookingType,
        'days_selected': daysSelected,
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
        if (pickupAddress != null) 'pickup_address': pickupAddress,
        'add_friend_seat': addFriendSeat,
        if (friendName != null) 'friend_name': friendName,
        if (friendContact != null) 'friend_contact': friendContact,
        if (friendPickupLat != null) 'friend_pickup_lat': friendPickupLat,
        if (friendPickupLng != null) 'friend_pickup_lng': friendPickupLng,
        if (friendPickupAddress != null) 'friend_pickup_address': friendPickupAddress,
      },
    );
    return Booking.fromJson(json);
  }

  Future<List<Booking>> listMyBookings() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/bookings', headers: h);
    return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Booking>> listDriverBookings() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/bookings/driver', headers: h);
    return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Booking> getBooking(String bookingId) async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/bookings/$bookingId', headers: h);
    return Booking.fromJson(json);
  }

  Future<FareBreakdown> getFareBreakdown(String bookingId) async {
    final h = await _authHeader();
    final json = await _api.getJson('$_base/bookings/$bookingId/fare', headers: h);
    return FareBreakdown.fromJson(json);
  }

  Future<Booking> approveBooking(String bookingId, {String? note}) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings/$bookingId/approve',
      headers: h,
      body: {if (note != null) 'note': note},
    );
    return Booking.fromJson(json);
  }

  Future<Booking> declineBooking(String bookingId, {String? reason}) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings/$bookingId/decline',
      headers: h,
      body: {if (reason != null) 'reason': reason},
    );
    return Booking.fromJson(json);
  }

  Future<Booking> requestPayment(String bookingId) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings/$bookingId/request-payment',
      headers: h,
      body: {},
    );
    return Booking.fromJson(json);
  }

  Future<void> notifyAbsence({
    required String bookingId,
    required String rideDate,
    String? reason,
  }) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/bookings/$bookingId/absence',
      headers: h,
      body: {
        'ride_date': rideDate,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  // ── Payment slips ────────────────────────────────────────────────────────────

  Future<String> uploadSlipToStorage(File imageFile, String bookingId) async {
    final uid = _auth.currentUser?.uid ?? 'unknown';
    final ref = FirebaseStorage.instance
        .ref()
        .child('payment_slips/$uid/$bookingId.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<PaymentSlip> submitPaymentSlip(String bookingId, String imageUrl) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings/$bookingId/payment-slip',
      headers: h,
      body: {'slip_image_url': imageUrl},
    );
    return PaymentSlip.fromJson(json);
  }

  Future<PaymentSlip> getPaymentSlip(String bookingId) async {
    final h = await _authHeader();
    final json = await _api.getJson(
      '$_base/bookings/$bookingId/payment-slip',
      headers: h,
    );
    return PaymentSlip.fromJson(json);
  }

  Future<PaymentSlip> verifyPaymentSlip(String bookingId) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings/$bookingId/payment-slip/verify',
      headers: h,
      body: {},
    );
    return PaymentSlip.fromJson(json);
  }

  Future<PaymentSlip> rejectPaymentSlip(String bookingId, String reason) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/bookings/$bookingId/payment-slip/reject',
      headers: h,
      body: {'rejection_reason': reason},
    );
    return PaymentSlip.fromJson(json);
  }

  // ── Ride sessions ────────────────────────────────────────────────────────────

  Future<RideSession?> getActiveSessionForRoute(String routeId) async {
    final h = await _authHeader();
    try {
      final json = await _api.getJson(
        '$_base/ride-sessions/active?route_id=${Uri.encodeComponent(routeId)}',
        headers: h,
      );
      return RideSession.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<RideSession> startRide(String routeId, String rideDate) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/ride-sessions',
      headers: h,
      body: {'route_id': routeId, 'ride_date': rideDate},
    );
    return RideSession.fromJson(json);
  }

  Future<RideSession> endRide(String sessionId) async {
    final h = await _authHeader();
    final json = await _api.postJson(
      '$_base/ride-sessions/$sessionId/end',
      headers: h,
      body: {},
    );
    return RideSession.fromJson(json);
  }

  Future<void> updateDriverLocation(
    String sessionId,
    double lat,
    double lng,
  ) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/ride-sessions/$sessionId/location',
      headers: h,
      body: {'lat': lat, 'lng': lng},
    );
  }

  Future<void> updatePassengerLocation(
    String sessionId,
    double lat,
    double lng,
  ) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/ride-sessions/$sessionId/passenger-location',
      headers: h,
      body: {'lat': lat, 'lng': lng},
    );
  }

  Future<void> signalArrival(String sessionId, String passengerId) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/ride-sessions/$sessionId/arrive',
      headers: h,
      body: {'passenger_id': passengerId},
    );
  }

  Future<void> confirmBoarded(String sessionId) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/ride-sessions/$sessionId/boarded',
      headers: h,
      body: {},
    );
  }

  Future<List<PassengerRideInfo>> getRidePassengers(String sessionId) async {
    final h = await _authHeader();
    final list = await _api.getList(
      '$_base/ride-sessions/$sessionId/passengers',
      headers: h,
    );
    return list
        .map((e) => PassengerRideInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markTripPaid({
    required String sessionId,
    required String bookingId,
    required String tripDate,
    required double amount,
    String paymentMethod = 'cash',
  }) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/ride-sessions/$sessionId/mark-paid',
      headers: h,
      body: {
        'booking_id': bookingId,
        'trip_date': tripDate,
        'amount': amount,
        'payment_method': paymentMethod,
      },
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  Future<void> registerFcmToken(String token) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/fcm-token',
      headers: h,
      body: {'token': token},
    );
  }

  Future<List<RouteNotification>> fetchNotifications() async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/notifications', headers: h);
    return list
        .map((e) => RouteNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Feedback ─────────────────────────────────────────────────────────────────

  Future<void> submitFeedback(RideFeedback feedback) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/feedback',
      headers: h,
      body: feedback.toJson(),
    );
  }

  Future<Map<String, dynamic>> getDriverRatingProfile(String driverId) async {
    final h = await _authHeader();
    return _api.getJson('$_base/feedback/driver/$driverId', headers: h);
  }

  Future<List<Map<String, dynamic>>> getDriverFeedbackEntries(String driverId) async {
    final h = await _authHeader();
    final list = await _api.getList('$_base/feedback/driver/$driverId/entries', headers: h);
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> refreshDriverSummary(String driverId) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/feedback/driver/$driverId/refresh-summary',
      headers: h,
      body: {},
    );
  }

  Future<void> generateRideSummary(String sessionId) async {
    final h = await _authHeader();
    await _api.postJson(
      '$_base/feedback/sessions/$sessionId/summary',
      headers: h,
      body: {},
    );
  }
}
