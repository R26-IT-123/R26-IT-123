import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/api_client.dart';
import '../models/ride_session.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({
    super.key,
    required this.routeId,
    required this.rideDate,
    required this.route,
    this.existingSession,
  });

  final String routeId;
  final String rideDate;
  final RoutePost route;
  final RideSession? existingSession;

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _api = RouteSharingApiService();

  RideSession? _session;
  List<PassengerRideInfo> _passengers = [];
  bool _starting = false;
  bool _ending = false;
  String? _error;
  int _gpsFailureCount = 0;

  final Set<String> _arrivedPassengers = {};
  final Set<String> _boardedPassengers = {};

  StreamSubscription<Position>? _gpsSub;
  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _passengerSubs = [];
  final Map<String, LatLng> _passengerLocations = {};

  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  double _carBearing = 0;
  BitmapDescriptor? _carIcon;
  late final Set<Polyline> _polylines;

  @override
  void initState() {
    super.initState();
    _polylines = _buildPolylines();
    _loadCarIcon();
    if (widget.existingSession != null) {
      _session = widget.existingSession;
      _startGpsStreaming(_session!.id);
      _startPassengerListeners(_session!.id, _session!.passengerIds);
      _loadPassengers(_session!.id);
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    for (final sub in _passengerSubs) {
      sub.cancel();
    }
    _mapController?.dispose();
    super.dispose();
  }

  void _loadCarIcon() {
    _buildCarMarkerIcon().then((icon) {
      if (mounted) setState(() => _carIcon = icon);
    });
  }

  static Future<BitmapDescriptor> _buildCarMarkerIcon() async {
    const int px = 96;
    final double s = px.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, s, s));

    // Drop shadow
    canvas.drawCircle(
      Offset(s * 0.5 + 2, s * 0.5 + 3),
      s * 0.41,
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Blue filled circle
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s * 0.41,
      Paint()..color = const Color(0xFF2563EB),
    );

    // White border
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s * 0.41,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07,
    );

    // White chevron pointing UP (north = 0°); rotation applied by Google Maps
    final chevron = Path()
      ..moveTo(s * 0.50, s * 0.17)
      ..lineTo(s * 0.73, s * 0.53)
      ..lineTo(s * 0.50, s * 0.43)
      ..lineTo(s * 0.27, s * 0.53)
      ..close();
    canvas.drawPath(chevron, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final img = await picture.toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(
      bytes!.buffer.asUint8List(),
      size: const Size(36, 36),
    );
  }

  Set<Polyline> _buildPolylines() {
    final encoded = widget.route.routePolyline;
    if (encoded == null || encoded.isEmpty) return {};
    final points = PolylinePoints()
        .decodePolyline(encoded)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    if (points.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF2563EB),
        width: 4,
      ),
    };
  }

  void _fitRouteBounds(GoogleMapController controller) {
    final sLat = widget.route.startLat;
    final sLng = widget.route.startLng;
    final dLat = widget.route.destinationLat;
    final dLng = widget.route.destinationLng;
    if (sLat == null || sLng == null || dLat == null || dLng == null) return;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(min(sLat, dLat), min(sLng, dLng)),
          northeast: LatLng(max(sLat, dLat), max(sLng, dLng)),
        ),
        60,
      ),
    );
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final sLat = widget.route.startLat;
    final sLng = widget.route.startLng;
    if (sLat != null && sLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(sLat, sLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ));
    }
    final dLat = widget.route.destinationLat;
    final dLng = widget.route.destinationLng;
    if (dLat != null && dLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(dLat, dLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.route.destination),
      ));
    }
    if (_currentLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('car'),
        position: _currentLatLng!,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: _carBearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }
    // Waypoint / boarding-stop markers
    for (final wp in widget.route.waypoints) {
      if (wp.lat == null || wp.lng == null) continue;
      markers.add(Marker(
        markerId: MarkerId('stop_${wp.order}'),
        position: LatLng(wp.lat!, wp.lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: 'Stop ${wp.order}',
          snippet: wp.address,
        ),
      ));
    }
    // Passenger live location markers
    for (final entry in _passengerLocations.entries) {
      markers.add(Marker(
        markerId: MarkerId('passenger_${entry.key}'),
        position: entry.value,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Passenger'),
      ));
    }
    return markers;
  }

  CameraPosition get _initialCamera {
    final sLat = widget.route.startLat;
    final sLng = widget.route.startLng;
    if (sLat != null && sLng != null) {
      return CameraPosition(target: LatLng(sLat, sLng), zoom: 13);
    }
    return const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 14);
  }

  static double _bearing(LatLng from, LatLng to) {
    const rad = pi / 180;
    final lat1 = from.latitude * rad;
    final lat2 = to.latitude * rad;
    final dLng = (to.longitude - from.longitude) * rad;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Future<void> _startRide() async {
    setState(() => _starting = true);
    try {
      final session = await _api.startRide(widget.routeId, widget.rideDate);
      if (mounted) {
        setState(() => _session = session);
        _startGpsStreaming(session.id);
        _startPassengerListeners(session.id, session.passengerIds);
        _loadPassengers(session.id);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 409) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
          Navigator.of(context).pop();
        } else {
          setState(() => _error = e.message);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to start ride.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startGpsStreaming(String sessionId) {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          if (_currentLatLng != null) {
            _carBearing = _bearing(_currentLatLng!, latLng);
          }
          _currentLatLng = latLng;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      }
      _api.updateDriverLocation(sessionId, pos.latitude, pos.longitude).then((_) {
        if (_gpsFailureCount > 0 && mounted) {
          setState(() => _gpsFailureCount = 0);
        }
      }).catchError((e) {
        debugPrint('Driver location update failed: $e');
        if (mounted) setState(() => _gpsFailureCount++);
      });
    });
  }

  void _startPassengerListeners(
      String sessionId, List<String> passengerIds) {
    for (final pid in passengerIds) {
      final sub = FirebaseFirestore.instance
          .collection('routesharing_live_locations')
          .doc('${sessionId}_$pid')
          .snapshots()
          .listen((snap) {
        if (!snap.exists || snap.data() == null) return;
        final data = snap.data()!;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat != null && lng != null && mounted) {
          setState(() => _passengerLocations[pid] = LatLng(lat, lng));
        }
        if (mounted) {
          setState(() {
            if (data['driver_arrived_at'] != null) _arrivedPassengers.add(pid);
            if (data['passenger_boarded'] == true) _boardedPassengers.add(pid);
          });
        }
      });
      _passengerSubs.add(sub);
    }
  }

  Future<void> _signalArrival(String passengerId) async {
    setState(() => _arrivedPassengers.add(passengerId));
    try {
      await _api.signalArrival(_session!.id, passengerId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _loadPassengers(String sessionId) async {
    try {
      final list = await _api.getRidePassengers(sessionId);
      if (mounted) setState(() => _passengers = list);
    } catch (_) {}
  }

  Future<void> _endRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End ride?'),
        content: const Text(
            'This will mark the ride as completed for all passengers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706)),
            child: const Text('End Ride'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _ending = true);
    _gpsSub?.cancel();
    try {
      final sessionId = _session!.id;
      await _api.endRide(sessionId);
      // Trigger AI summary generation (best-effort — don't block navigation)
      _api.generateRideSummary(sessionId).catchError((_) {});
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  void _zoomIn() => _mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());
  void _goToMyLocation() {
    if (_currentLatLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
      );
    }
  }

  Future<void> _markPaid(PassengerRideInfo p) async {
    try {
      await _api.markTripPaid(
        sessionId: _session!.id,
        bookingId: p.bookingId ?? p.passengerId,
        tripDate: widget.rideDate,
        amount: p.fareForToday,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip marked as paid.')),
        );
        _loadPassengers(_session!.id);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF374151)),
                  ),
                  const Expanded(
                    child: Text(
                      'Active Ride',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (_session != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record,
                              size: 10, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Date card ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Text(
                            widget.rideDate,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_gpsFailureCount >= 3) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location sharing interrupted — passengers may not see your position',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Color(0xFFEF4444))),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Route map ────────────────────────────────
                    SizedBox(
                      height: 300,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: GoogleMap(
                              initialCameraPosition: _initialCamera,
                              markers: _markers,
                              polylines: _polylines,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              onMapCreated: (c) {
                                _mapController = c;
                                _fitRouteBounds(c);
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 8,
                            child: Column(
                              children: [
                                _MapControlBtn(
                                  icon: Icons.add_rounded,
                                  onTap: _zoomIn,
                                ),
                                const SizedBox(height: 6),
                                _MapControlBtn(
                                  icon: Icons.remove_rounded,
                                  onTap: _zoomOut,
                                ),
                                const SizedBox(height: 6),
                                _MapControlBtn(
                                  icon: Icons.my_location_rounded,
                                  onTap: _goToMyLocation,
                                  active: _currentLatLng != null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Passengers ───────────────────────────────
                    if (_session != null && _passengers.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_passengers.length} passenger${_passengers.length > 1 ? "s" : ""} today',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._passengers
                                .map((p) => _PassengerTile(
                                      passenger: p,
                                      hasArrived: _arrivedPassengers.contains(p.passengerId),
                                      hasBoarded: _boardedPassengers.contains(p.passengerId),
                                      onArrived: _session != null &&
                                              !_arrivedPassengers.contains(p.passengerId)
                                          ? () => _signalArrival(p.passengerId)
                                          : null,
                                      onMarkPaid:
                                          p.paidToday ? null : () => _markPaid(p),
                                    )),
                          ],
                        ),
                      ),
                    ],

                    if (_session == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.directions_car_rounded,
                                size: 52, color: Color(0xFFD1D5DB)),
                            const SizedBox(height: 14),
                            const Text(
                              'Ready to start your ride?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tapping Start will begin live GPS sharing with your passengers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom action ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: _session == null
                    ? FilledButton.icon(
                        onPressed: _starting ? null : _startRide,
                        icon: const Icon(Icons.play_circle_rounded,
                            size: 20),
                        label: _starting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('Start Ride'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _ending ? null : _endRide,
                        icon: const Icon(Icons.stop_circle_rounded,
                            size: 20),
                        label: _ending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('End Ride'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map control button ────────────────────────────────────────────────────────

class _MapControlBtn extends StatelessWidget {
  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? const Color(0xFF2563EB) : const Color(0xFF374151),
        ),
      ),
    );
  }
}

// ── Passenger tile ────────────────────────────────────────────────────────────

class _PassengerTile extends StatelessWidget {
  const _PassengerTile({
    required this.passenger,
    this.onMarkPaid,
    this.hasArrived = false,
    this.hasBoarded = false,
    this.onArrived,
  });

  final PassengerRideInfo passenger;
  final VoidCallback? onMarkPaid;
  final bool hasArrived;
  final bool hasBoarded;
  final VoidCallback? onArrived;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    passenger.seatNumber?.toString() ?? '?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger.passengerName ?? 'Seat #${passenger.seatNumber ?? "–"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'LKR ${passenger.fareForToday.toStringAsFixed(0)} today',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              if (passenger.paidToday)
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: Color(0xFF16A34A))
              else if (onMarkPaid != null)
                TextButton(
                  onPressed: onMarkPaid,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                  child: const Text('Mark paid',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (hasBoarded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car_rounded,
                    size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                const Text(
                  'Boarded',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ] else if (hasArrived) ...[
            const SizedBox(height: 8),
            const Text(
              'Waiting for passenger to confirm boarding...',
              style: TextStyle(fontSize: 11, color: Color(0xFFD97706)),
            ),
          ] else if (onArrived != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onArrived,
                icon: const Icon(Icons.location_on_rounded, size: 14),
                label: const Text("I've arrived at pickup",
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
