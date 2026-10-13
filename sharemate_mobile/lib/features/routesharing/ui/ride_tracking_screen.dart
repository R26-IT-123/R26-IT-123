import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/api_client.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'feedback_screen.dart';

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({
    super.key,
    required this.sessionId,
    required this.driverId,
    required this.route,
    this.passengerId,
  });

  final String sessionId;
  final String driverId;
  final RoutePost route;
  final String? passengerId;

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final _api = RouteSharingApiService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _locationSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pickupSub;
  StreamSubscription<Position>? _gpsSub;

  GoogleMapController? _mapController;

  // Driver position (from Firestore)
  double? _driverLat;
  double? _driverLng;
  double _driverBearing = 0;
  DateTime? _lastUpdated;

  // Passenger's own position (from device GPS)
  LatLng? _myLatLng;

  bool _rideEnded = false;
  bool _feedbackPushed = false;
  bool _driverArrived = false;
  bool _boardingConfirmed = false;
  bool _arrivalDialogShown = false;
  int _gpsFailureCount = 0;
  bool _followDriver = true;
  BitmapDescriptor? _carIcon;

  late final Set<Polyline> _polylines;

  @override
  void initState() {
    super.initState();
    _polylines = _buildPolylines();
    _listenToDriverLocation();
    _listenToSession();
    _startOwnLocationStream();
    _listenForArrivalSignal();
    _loadCarIcon();
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
    if (sLat == null || sLng == null || dLat == null || dLng == null) {
      if (sLat != null && sLng != null) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(sLat, sLng), 13),
        );
      }
      return;
    }
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

  // ── Passenger shares their own location ────────────────────────────────────

  void _startOwnLocationStream() {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() => _myLatLng = LatLng(pos.latitude, pos.longitude));
      }
      _api
          .updatePassengerLocation(
            widget.sessionId,
            pos.latitude,
            pos.longitude,
          )
          .then((_) {
        if (_gpsFailureCount > 0 && mounted) {
          setState(() => _gpsFailureCount = 0);
        }
      }).catchError((e) {
        debugPrint('Passenger location update failed: $e');
        if (mounted) setState(() => _gpsFailureCount++);
      });
    });
  }

  // ── Driver live location from Firestore ────────────────────────────────────

  void _listenToDriverLocation() {
    _locationSub = FirebaseFirestore.instance
        .collection('routesharing_live_locations')
        .doc('${widget.sessionId}_driver')
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final data = snap.data()!;
      if (!mounted) return;

      final newLat = (data['lat'] as num?)?.toDouble();
      final newLng = (data['lng'] as num?)?.toDouble();

      setState(() {
        if (_driverLat != null &&
            _driverLng != null &&
            newLat != null &&
            newLng != null) {
          _driverBearing = _bearing(
            LatLng(_driverLat!, _driverLng!),
            LatLng(newLat, newLng),
          );
        }
        _driverLat = newLat;
        _driverLng = newLng;
        final tsRaw = data['timestamp'];
        if (tsRaw is Timestamp) {
          _lastUpdated = tsRaw.toDate();
        } else if (tsRaw is String) {
          _lastUpdated = DateTime.tryParse(tsRaw);
        }
      });

      if (_followDriver && _driverLat != null && _driverLng != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(_driverLat!, _driverLng!)),
        );
      }
    });
  }

  void _listenToSession() {
    _sessionSub = FirebaseFirestore.instance
        .collection('routesharing_ride_sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final data = snap.data()!;
      if (mounted && data['status'] == 'completed') {
        setState(() => _rideEnded = true);
        _gpsSub?.cancel();
        if (!_feedbackPushed) {
          _feedbackPushed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FeedbackScreen(
                    sessionId: widget.sessionId,
                    driverId: widget.driverId,
                  ),
                ),
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _sessionSub?.cancel();
    _pickupSub?.cancel();
    _gpsSub?.cancel();
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

  void _zoomIn() => _mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());

  void _goToMyLocation() {
    if (_myLatLng != null) {
      setState(() => _followDriver = false);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_myLatLng!, 16),
      );
    }
  }

  void _resumeFollowDriver() {
    setState(() => _followDriver = true);
    if (_driverLat != null && _driverLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(_driverLat!, _driverLng!)),
      );
    }
  }

  void _listenForArrivalSignal() {
    final uid = widget.passengerId?.isNotEmpty == true
        ? widget.passengerId
        : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _pickupSub = FirebaseFirestore.instance
        .collection('routesharing_live_locations')
        .doc('${widget.sessionId}_$uid')
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null || !mounted) return;
      final data = snap.data()!;

      if (data['passenger_boarded'] == true && mounted) {
        setState(() => _boardingConfirmed = true);
        return;
      }

      if (data['driver_arrived_at'] != null &&
          !_arrivalDialogShown &&
          !_boardingConfirmed &&
          mounted) {
        setState(() => _driverArrived = true);
        _arrivalDialogShown = true;
        _showBoardingDialog();
      }
    });
  }

  Future<void> _showBoardingDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Driver has arrived!'),
        content: const Text(
            'Your driver is at your pickup location. Confirm you\'ve boarded the vehicle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            child: const Text("I've boarded"),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await RouteSharingApiService().confirmBoarded(widget.sessionId);
        if (mounted) setState(() => _boardingConfirmed = true);
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
          _arrivalDialogShown = false;
        }
      }
    }
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

  Set<Marker> get _markers {
    final markers = <Marker>{};

    // Start marker
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

    // Destination marker
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

    // Driver car marker (from Firestore)
    if (_driverLat != null && _driverLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(_driverLat!, _driverLng!),
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: _driverBearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'Driver',
          snippet: _lastUpdated != null
              ? 'Updated ${_timeSince(_lastUpdated!)} ago'
              : null,
        ),
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
    // Passenger's own location (from device GPS)
    if (_myLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: _myLatLng!,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(title: 'You'),
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
                      'Track Ride',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (!_rideEnded)
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

            // ── Status banner ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _rideEnded
                  ? _Banner(
                      icon: Icons.check_circle_rounded,
                      title: 'Ride completed',
                      subtitle: 'Your driver has ended the ride.',
                      color: const Color(0xFF16A34A),
                      bg: const Color(0xFFF0FDF4),
                    )
                  : _boardingConfirmed
                      ? _Banner(
                          icon: Icons.directions_car_rounded,
                          title: 'You\'ve boarded!',
                          subtitle: 'Enjoy your ride. The vehicle is moving in real time on the map.',
                          color: const Color(0xFF16A34A),
                          bg: const Color(0xFFF0FDF4),
                        )
                      : _driverArrived
                          ? _ArrivalBanner(
                              onConfirm: () {
                                _arrivalDialogShown = true;
                                _showBoardingDialog();
                              },
                            )
                          : _driverLat == null
                              ? _Banner(
                                  icon: Icons.hourglass_empty_rounded,
                                  title: 'Waiting for driver',
                                  subtitle:
                                      'Your driver hasn\'t started moving yet. Their live location will appear here.',
                                  color: const Color(0xFFD97706),
                                  bg: const Color(0xFFFEF3C7),
                                )
                              : _Banner(
                                  icon: Icons.directions_car_rounded,
                                  title: 'Driver is on the way',
                                  subtitle: _lastUpdated != null
                                      ? 'Last updated ${_timeSince(_lastUpdated!)} ago'
                                      : 'Live location active',
                                  color: const Color(0xFF2563EB),
                                  bg: const Color(0xFFEFF6FF),
                                ),
            ),

            if (_gpsFailureCount >= 3) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
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
                          'Location sharing interrupted — your position may not reach the driver',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Map ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _fitRouteBounds(controller);
                        },
                      ),
                    ),
                    // Follow-driver restore button (visible when user panned away)
                    if (!_followDriver)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _MapControlBtn(
                          icon: Icons.directions_car_rounded,
                          onTap: _resumeFollowDriver,
                          active: true,
                          tooltip: 'Follow driver',
                        ),
                      ),
                    // Zoom + My Location buttons
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
                            active: _myLatLng != null && !_followDriver,
                          ),
                        ],
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

  static String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

// ── Map control button ────────────────────────────────────────────────────────

class _MapControlBtn extends StatelessWidget {
  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
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
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

// ── Arrival banner ────────────────────────────────────────────────────────────

class _ArrivalBanner extends StatelessWidget {
  const _ArrivalBanner({required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, size: 24, color: Color(0xFF16A34A)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver has arrived!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your driver is at your pickup location.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: const Text("Confirm I've Boarded"),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
