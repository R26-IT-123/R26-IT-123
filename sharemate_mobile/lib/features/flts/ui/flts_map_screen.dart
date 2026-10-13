import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/bus_route.dart';
import '../models/route_incident.dart';
import '../services/eta_service.dart';
import '../services/flts_api_service.dart';
import '../services/gps_sharing_service.dart';
import 'friendzone_screen.dart';
import 'widgets/route_selector_sheet.dart';
// cloud_firestore kept only for the feedback fallback path


const LatLng _kSliitLocation = LatLng(
  BusRoute.campusLat,
  BusRoute.campusLng,
);
const double _kDefaultZoom = 14.0;

class FltsMapScreen extends StatefulWidget {
  const FltsMapScreen({super.key, this.preferredRouteId});

  final String? preferredRouteId;

  @override
  State<FltsMapScreen> createState() => _FltsMapScreenState();
}

class _FltsMapScreenState extends State<FltsMapScreen> {
  GoogleMapController? _mapController;
  BusRoute? _selectedRoute;
  // Canonical outbound (campus → town) route backing _selectedRoute, kept
  // separately so direction can be toggled without losing the original.
  BusRoute? _forwardRoute;
  bool _isReversed = false;
  bool _isPanelMinimized = false;
  LatLng? _currentPosition;
  bool _isLocating = false;

  // ── GPS sharing ────────────────────────────────────────────────────────────
  // Uses the app-wide singleton so an active share survives navigating away
  // from this screen instead of being torn down in dispose().
  late final GpsSharingService _gpsSharingService = GpsSharingService.instance
    ..onError = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing error: $msg'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
    ..onAutoStopped = () {
      if (!mounted) return;
      final vehicleNumber = _currentVehicleNumber;
      final route = _selectedRoute;
      _stopMyBusTracking();
      setState(() {
        _isSharing = false;
        _currentVehicleNumber = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sharing stopped — looks like you left the bus.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 5),
        ),
      );
      if (route != null && !_feedbackGivenThisSession) {
        Future.delayed(const Duration(milliseconds: 600), () async {
          if (!mounted) return;
          final resolvedVn = (vehicleNumber?.isNotEmpty ?? false)
              ? vehicleNumber!
              : await _fetchRouteVehicleNumber();
          if (resolvedVn.isNotEmpty && mounted) {
            _showFeedbackSheet(resolvedVn, route.id);
          }
        });
      }
    };
  bool _isSharing = false;
  String? _currentVehicleNumber;
  bool _feedbackGivenThisSession = false;

  // ── Live bus marker (centroid) + ETA ──────────────────────────────────────
  Timer? _liveGpsTimer;
  final FltsApiService _fltsApiService = FltsApiService();
  Set<Marker> _markers = {};
  Set<Marker> _routeEndMarkers = {};
  Set<Marker> _myBusMarker = {};
  Set<Polyline> _polylines = {};
  int _livePassengerCount = 0;
  StreamSubscription<Position>? _myPositionSub;
  BitmapDescriptor? _busMarkerIcon;

  // Speed tracking — compare successive centroids
  LatLng? _previousCentroid;
  DateTime? _previousCentroidTime;
  Map<String, int?> _etaMinutes = {};
  double? _busSpeedKmh;

  // Whether anyone sharing on the selected route has entered a vehicle
  // number — kept as a persistent subscription (not a StreamBuilder rebuilt
  // by the 5s poll cycle) so the "Rate this bus" button doesn't flicker.
  // Combines two sources: currently-live riders, and the persisted per-route
  // record (so the number survives its original reporter having left).
  bool _hasVehicleNumber = false;
  bool _liveGpsHasVehicleNumber = false;
  bool _persistedVehicleNumberFresh = false;
  StreamSubscription<QuerySnapshot>? _vehicleNumberSub;
  StreamSubscription<DocumentSnapshot>? _routeActivitySub;

  // ── Traffic incident reporting ──────────────────────────────────────────
  List<RouteIncident> _incidents = [];
  Timer? _incidentPollTimer;
  bool _isReportingIncident = false;
  // Set on long-press so the reported incident uses the pinned spot instead
  // of the reporter's live GPS position.
  LatLng? _pendingIncidentLocation;

  // The FCM topic ("flts_route_{id}") this device is currently subscribed
  // to for push alerts — kept separate from the student's saved profile
  // preferred route, since students routinely view/share a *different*
  // route ad hoc via the route selector, and would otherwise never be
  // subscribed to get pushes for it.
  String? _subscribedRouteTopicId;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _locateUser();
    _initBusMarker();

    final activeRouteId = _gpsSharingService.activeRouteId;
    if (_gpsSharingService.isSharing && activeRouteId != null) {
      // Resume a share already in progress (started from a previous visit
      // to this screen, kept alive by the singleton after we navigated away).
      const returnSuffix = '_return';
      final isReversed = activeRouteId.endsWith(returnSuffix);
      final baseId = isReversed
          ? activeRouteId.substring(0, activeRouteId.length - returnSuffix.length)
          : activeRouteId;
      final matches = BusRoute.sliitRoutes.where((r) => r.id == baseId);
      final forward = matches.isNotEmpty ? matches.first : BusRoute.sliitRoutes.first;
      final route = isReversed ? forward.returnTrip : forward;
      _forwardRoute = forward;
      _isReversed = isReversed;
      _selectedRoute = route;
      _isSharing = true;
      _currentVehicleNumber = _gpsSharingService.activeVehicleNumber;
      _startLiveListener(route);
      _subscribeToRouteTopic(route.id);
      _startMyBusTracking();
    } else if (widget.preferredRouteId != null) {
      final route = BusRoute.sliitRoutes.firstWhere(
        (r) => r.id == widget.preferredRouteId,
        orElse: () => BusRoute.sliitRoutes.first,
      );
      _forwardRoute = route;
      _selectedRoute = route;
      _startLiveListener(route);
      _subscribeToRouteTopic(route.id);
    }
  }

  @override
  void dispose() {
    _liveGpsTimer?.cancel();
    _incidentPollTimer?.cancel();
    _vehicleNumberSub?.cancel();
    _routeActivitySub?.cancel();
    _myPositionSub?.cancel();
    // Deliberately NOT stopping GPS sharing here — an active share should
    // keep running after the student navigates away from this screen. It's
    // only stopped by an explicit user action (the Stop Sharing button,
    // switching/reversing the route, or the cluster-distance auto-stop).
    _unsubscribeFromCurrentRouteTopic();
    _mapController?.dispose();
    super.dispose();
  }

  /// Switches this device's FCM subscription to [routeId] so it receives
  /// "someone joined"/"incident reported" pushes for whichever route is
  /// actually selected on this screen right now.
  void _subscribeToRouteTopic(String routeId) {
    if (_subscribedRouteTopicId == routeId) return;
    _unsubscribeFromCurrentRouteTopic();
    _subscribedRouteTopicId = routeId;
    FirebaseMessaging.instance.subscribeToTopic('flts_route_$routeId');
  }

  void _unsubscribeFromCurrentRouteTopic() {
    final previous = _subscribedRouteTopicId;
    if (previous == null) return;
    _subscribedRouteTopicId = null;
    // Never unsubscribe the student's saved preferred-route topic here —
    // student_home_page subscribes to it independently on load and relies
    // on it staying subscribed for push alerts even after this screen
    // closes (or the user switches to viewing a different route ad hoc).
    if (previous == widget.preferredRouteId) return;
    FirebaseMessaging.instance.unsubscribeFromTopic('flts_route_$previous');
  }

  // ── My bus position marker ────────────────────────────────────────────────

  void _startMyBusTracking() {
    _myPositionSub?.cancel();
    _myPositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _myBusMarker = {
          Marker(
            markerId: const MarkerId('my_bus'),
            position: LatLng(position.latitude, position.longitude),
            icon: _busMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
            zIndex: 3,
            infoWindow: const InfoWindow(title: 'You (on bus)'),
          ),
        };
      });
    });
  }

  void _stopMyBusTracking() {
    _myPositionSub?.cancel();
    _myPositionSub = null;
    setState(() => _myBusMarker = {});
  }

  // ── Bus icon ───────────────────────────────────────────────────────────────

  Future<void> _initBusMarker() async {
    const double size = 64;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Green filled circle
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = const Color(0xFF24AE59),
    );
    // White border ring
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Bus emoji centred inside circle
    final TextPainter tp = TextPainter(
      text: const TextSpan(text: '🚌', style: TextStyle(fontSize: 30)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );

    final ui.Image img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? data =
        await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || data == null) return;
    setState(() {
      _busMarkerIcon = BitmapDescriptor.bytes(data.buffer.asUint8List());
    });
  }

  // ── Route polyline ─────────────────────────────────────────────────────────

  Future<void> _fetchRoadPolyline(BusRoute route) async {
    if (route.stops.isEmpty) return;

    final waypoints = [
      LatLng(route.originLat, route.originLng),
      ...route.stops.map((s) => LatLng(s.lat, s.lng)),
    ];

    List<LatLng> routePoints = waypoints;

    try {
      final coords =
          waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords'
        '?overview=full&geometries=geojson',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coordinates =
              routes[0]['geometry']['coordinates'] as List;
          routePoints = coordinates
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('FLTS OSRM routing error (straight-line fallback): $e');
    }

    if (!mounted) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('bus_route'),
          points: routePoints,
          color: const Color(0xFF2979FF),
          width: 7,
          zIndex: 2,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
      _routeEndMarkers = {
        Marker(
          markerId: const MarkerId('route_origin'),
          position: waypoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow:
              InfoWindow(title: route.origin, snippet: 'Start'),
        ),
        Marker(
          markerId: const MarkerId('route_destination'),
          position: waypoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
          infoWindow:
              InfoWindow(title: route.destination, snippet: 'End'),
        ),
      };
    });
  }

  // ── Live centroid listener ─────────────────────────────────────────────────

  void _startLiveListener(BusRoute route) {
    _liveGpsTimer?.cancel();
    _incidentPollTimer?.cancel();

    _fetchRoadPolyline(route);

    // Fetch immediately, then poll every 5 s — matches the GPS tick interval.
    _pollPassengers(route.id);
    _liveGpsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollPassengers(route.id),
    );

    // Incidents change far less often — poll on a slower cadence.
    _pollIncidents(route.id);
    _incidentPollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pollIncidents(route.id),
    );

    // Persistent listeners (not rebuilt every poll) so the "Rate this bus"
    // button doesn't flicker hidden while its data momentarily resets.
    // Two sources are combined: live_gps (riders currently sharing) and the
    // persisted per-route record (survives the number-entering rider having
    // already left — see _fetchRouteVehicleNumber for the same fallback).
    _vehicleNumberSub?.cancel();
    _liveGpsHasVehicleNumber = false;
    _vehicleNumberSub = FirebaseFirestore.instance
        .collection('live_gps')
        .where('routeId', isEqualTo: route.id)
        .snapshots()
        .listen((snapshot) {
      _liveGpsHasVehicleNumber = snapshot.docs.any((doc) {
        final vn = doc.data()['vehicleNumber'] as String?;
        return vn != null && vn.isNotEmpty;
      });
      _recomputeHasVehicleNumber();
    });

    _routeActivitySub?.cancel();
    _persistedVehicleNumberFresh = false;
    _routeActivitySub = FirebaseFirestore.instance
        .collection('route_activity')
        .doc(route.id)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      final vn = data?['currentVehicleNumber'] as String?;
      final updatedAt = (data?['vehicleNumberUpdatedAt'] as Timestamp?)?.toDate();
      _persistedVehicleNumberFresh = vn != null &&
          vn.isNotEmpty &&
          updatedAt != null &&
          DateTime.now().difference(updatedAt) <= _vehicleNumberFreshWindow;
      _recomputeHasVehicleNumber();
    });
  }

  void _recomputeHasVehicleNumber() {
    final has = _liveGpsHasVehicleNumber || _persistedVehicleNumberFresh;
    if (mounted && has != _hasVehicleNumber) {
      setState(() => _hasVehicleNumber = has);
    }
  }

  void _stopLiveListener() {
    _liveGpsTimer?.cancel();
    _liveGpsTimer = null;
    _incidentPollTimer?.cancel();
    _incidentPollTimer = null;
    _vehicleNumberSub?.cancel();
    _vehicleNumberSub = null;
    _routeActivitySub?.cancel();
    _routeActivitySub = null;
    setState(() {
      _markers = {};
      _routeEndMarkers = {};
      _polylines = {};
      _livePassengerCount = 0;
      _previousCentroid = null;
      _previousCentroidTime = null;
      _etaMinutes = {};
      _busSpeedKmh = null;
      _incidents = [];
      _hasVehicleNumber = false;
      _liveGpsHasVehicleNumber = false;
      _persistedVehicleNumberFresh = false;
    });
  }

  Future<void> _pollIncidents(String routeId) async {
    if (_selectedRoute == null) return;
    try {
      final incidents =
          await _fltsApiService.fetchRouteIncidents(routeId: routeId);
      if (!mounted) return;
      setState(() => _incidents = incidents);
    } catch (e) {
      debugPrint('FLTS incidents poll error (non-fatal): $e');
    }
  }

  Future<void> _pollPassengers(String routeId) async {
    final route = _selectedRoute;
    if (route == null) return;

    Map<String, dynamic> data;
    try {
      data = await _fltsApiService.fetchPassengers(routeId: routeId);
    } catch (e) {
      debugPrint('FLTS passengers poll error (non-fatal): $e');
      return;
    }

    if (!mounted) return;

    final count = (data['active_count'] as num?)?.toInt() ?? 0;
    final centroidLat = (data['centroid_lat'] as num?)?.toDouble();
    final centroidLng = (data['centroid_lng'] as num?)?.toDouble();

    if (count == 0 || centroidLat == null || centroidLng == null) {
      setState(() {
        _markers = {};
        _livePassengerCount = 0;
        _previousCentroid = null;
        _previousCentroidTime = null;
        _etaMinutes = {};
        _busSpeedKmh = null;
      });
      return;
    }

    final centroid = LatLng(centroidLat, centroidLng);
    final now = DateTime.now();

    final elapsedSeconds = _previousCentroidTime != null
        ? now.difference(_previousCentroidTime!).inSeconds.toDouble()
        : null;

    final speed = EtaService.deriveSpeedKmh(
      current: centroid,
      previous: _previousCentroid,
      elapsedSeconds: elapsedSeconds,
    );

    final etas = EtaService.calculateEtaMinutes(
      busPosition: centroid,
      speedKmh: speed,
      stops: route.stops,
    );

    final busMarker = Marker(
      markerId: const MarkerId('live_bus'),
      position: centroid,
      icon: _busMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: '${route.destination} route bus',
        snippet: '$count student${count == 1 ? '' : 's'} sharing live',
      ),
      anchor: const Offset(0.5, 0.5),
    );

    setState(() {
      _markers = {busMarker};
      _livePassengerCount = count;
      _previousCentroid = centroid;
      _previousCentroidTime = now;
      _etaMinutes = etas;
      _busSpeedKmh = speed;
    });
  }


  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _locateUser() async {
    setState(() => _isLocating = true);
    try {
      final permission = await _resolveLocationPermission();
      if (!permission) {
        setState(() => _isLocating = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = latLng;
        _isLocating = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, _kDefaultZoom),
      );
    } catch (_) {
      setState(() => _isLocating = false);
    }
  }

  Future<bool> _resolveLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ── GPS Sharing ────────────────────────────────────────────────────────────

  Future<void> _toggleSharing() async {
    if (_selectedRoute == null) return;

    if (_isSharing) {
      final vehicleNumber = _currentVehicleNumber;
      final routeId = _selectedRoute!.id;
      await _gpsSharingService.stopSharing();
      _stopMyBusTracking();
      setState(() {
        _isSharing = false;
        _currentVehicleNumber = null;
      });
      if (mounted) _showSnack('Stopped sharing — removed from live map.', false);
      if (mounted && !_feedbackGivenThisSession) {
        final resolvedVn = (vehicleNumber?.isNotEmpty ?? false)
            ? vehicleNumber!
            : await _fetchRouteVehicleNumber();
        if (resolvedVn.isNotEmpty && mounted) {
          await _showFeedbackSheet(resolvedVn, routeId);
        }
      }
    } else {
      final vehicleNumber = await _showVehicleNumberDialog();
      if (vehicleNumber == null) return; // null = user pressed Cancel
      await _gpsSharingService.startSharing(
        _selectedRoute!.id,
        vehicleNumber: vehicleNumber,
      );
      _startMyBusTracking();
      setState(() {
        _isSharing = true;
        _currentVehicleNumber = vehicleNumber; // may be "" if skipped
        _feedbackGivenThisSession = false;
      });
      if (mounted) _showSnack('Live sharing started — helping your route!', true);
    }
  }

  Future<String?> _showVehicleNumberDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Enter Vehicle Number',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the vehicle registration number of the bus you are on.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. NA-1234',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF24AE59),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.directions_bus_rounded,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text(
              'Skip',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF24AE59),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Start Sharing'),
          ),
        ],
      ),
    );
  }

  /// How long a persisted route-level vehicle number stays valid after the
  /// last rider who confirmed it went stale — long enough to cover one
  /// commute, short enough not to leak into an unrelated later trip.
  static const _vehicleNumberFreshWindow = Duration(hours: 3);

  /// Returns the vehicle number to pre-fill in the feedback sheet.
  /// Priority: user-entered → GPS sharing service → live Firestore live_gps
  /// docs → the persisted per-route record (survives the original reporter
  /// having already stopped sharing) → "".
  Future<String> _fetchRouteVehicleNumber() async {
    if (_currentVehicleNumber != null && _currentVehicleNumber!.isNotEmpty) {
      return _currentVehicleNumber!;
    }
    final serviceVn = _gpsSharingService.activeVehicleNumber;
    if (serviceVn != null && serviceVn.isNotEmpty) return serviceVn;
    if (_selectedRoute == null) return '';
    final routeId = _selectedRoute!.id;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('live_gps')
          .where('routeId', isEqualTo: routeId)
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        final vn = doc.data()['vehicleNumber'] as String?;
        if (vn != null && vn.isNotEmpty) return vn;
      }
    } catch (_) {}
    try {
      final activityDoc = await FirebaseFirestore.instance
          .collection('route_activity')
          .doc(routeId)
          .get();
      final data = activityDoc.data();
      final vn = data?['currentVehicleNumber'] as String?;
      final updatedAt = (data?['vehicleNumberUpdatedAt'] as Timestamp?)?.toDate();
      if (vn != null &&
          vn.isNotEmpty &&
          updatedAt != null &&
          DateTime.now().difference(updatedAt) <= _vehicleNumberFreshWindow) {
        return vn;
      }
    } catch (_) {}
    return '';
  }

  Future<void> _openFeedback() async {
    if (_selectedRoute == null) return;
    final vehicleNumber = await _fetchRouteVehicleNumber();
    if (!mounted) return;
    await _showFeedbackSheet(vehicleNumber, _selectedRoute!.id);
  }

  Future<void> _showFeedbackSheet(
    String vehicleNumber,
    String routeId,
  ) async {
    int selectedRating = 0;
    String? selectedType;
    final commentController = TextEditingController();
    const types = [
      'Overcrowded',
      'On Time',
      'Driver Behavior',
      'Clean',
      'Other',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.rate_review_rounded,
                      color: Color(0xFF16A34A),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Rate your journey',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (vehicleNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vehicleNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'How was your ride?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () =>
                          setModalState(() => selectedRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Feedback type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.map((type) {
                    final selected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setModalState(
                        () => selectedType = selected ? null : type,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF16A34A)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Comment (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Tell us about your experience...',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF24AE59),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedRating == 0
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF24AE59),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: selectedRating == 0
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                _feedbackGivenThisSession = true;
                                await _submitFeedback(
                                  vehicleNumber: vehicleNumber,
                                  routeId: routeId,
                                  rating: selectedRating,
                                  type: selectedType ?? '',
                                  comment: commentController.text.trim(),
                                );
                              },
                        child: const Text(
                          'Submit Feedback',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback({
    required String vehicleNumber,
    required String routeId,
    required int rating,
    required String type,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Primary path: backend validates and writes to Firestore
    try {
      await FltsApiService().submitFeedback(
        vehicleNumber: vehicleNumber,
        routeId: routeId,
        rating: rating,
        type: type,
        comment: comment,
      );
      if (mounted) _showSnack('Thank you for your feedback!', true);
      return;
    } catch (e) {
      debugPrint('FLTS feedback backend unavailable ($e); using direct Firestore fallback.');
    }

    // Fallback: write directly to Firestore
    try {
      await FirebaseFirestore.instance.collection('bus_feedback').add({
        'vehicleNumber': vehicleNumber,
        'routeId': routeId,
        'userId': user.uid,
        'displayName': user.displayName ?? 'Student',
        'rating': rating,
        'type': type,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSnack('Thank you for your feedback!', true);
    } catch (e) {
      debugPrint('FLTS feedback submit error: $e');
    }
  }

  void _showSnack(String message, bool positive) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            positive ? const Color(0xFF24AE59) : const Color(0xFF6B7280),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ── Traffic incident reporting ────────────────────────────────────────────

  static const Map<String, double> _incidentHues = {
    'traffic_jam': BitmapDescriptor.hueOrange,
    'accident': BitmapDescriptor.hueRed,
    'road_closure': BitmapDescriptor.hueViolet,
    'bus_breakdown': BitmapDescriptor.hueYellow,
    'heavy_rain': BitmapDescriptor.hueAzure,
    'other': BitmapDescriptor.hueRose,
  };

  Set<Marker> _buildIncidentMarkers() {
    return _incidents.map((incident) {
      return Marker(
        markerId: MarkerId('incident_${incident.incidentId}'),
        position: LatLng(incident.lat, incident.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _incidentHues[incident.incidentType] ?? BitmapDescriptor.hueRose,
        ),
        onTap: () => _showIncidentDetails(incident),
      );
    }).toSet();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showIncidentDetails(RouteIncident incident) {
    final isMine =
        incident.reportedByUid == FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    incident.typeIcon,
                    color: const Color(0xFFEF4444),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      incident.typeLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(incident.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              if (incident.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  incident.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
              if (isMine) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _resolveIncident(incident);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text('Mark as resolved'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolveIncident(RouteIncident incident) async {
    try {
      await _fltsApiService.resolveIncident(incidentId: incident.incidentId);
      if (_selectedRoute != null) await _pollIncidents(_selectedRoute!.id);
      if (!mounted) return;
      _showSnack('Incident marked as resolved.', true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not resolve incident: $e', false);
    }
  }

  void _handleMapLongPress(LatLng position) {
    if (_selectedRoute == null) return;
    setState(() => _pendingIncidentLocation = position);
    _openReportIncidentSheet(location: position);
  }

  Future<void> _openReportIncidentSheet({LatLng? location}) async {
    final route = _selectedRoute;
    if (route == null) return;

    String? selectedType;
    final descriptionController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Icon(
                        Icons.report_gmailerrorred_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Report an incident',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Let others on ${route.origin} → ${route.destination} know what\'s happening.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        location != null
                            ? Icons.push_pin_rounded
                            : Icons.my_location_rounded,
                        size: 13,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        location != null
                            ? 'Using the spot you pinned on the map'
                            : 'Using your current location',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RouteIncident.typeLabels.entries.map((entry) {
                      final selected = selectedType == entry.key;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedType = entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                RouteIncident.typeIcons[entry.key] ??
                                    Icons.warning_amber_rounded,
                                size: 15,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLength: 140,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add details (optional)',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: selectedType == null || _isReportingIncident
                          ? null
                          : () async {
                              setModalState(() => _isReportingIncident = true);
                              await _submitIncidentReport(
                                route: route,
                                incidentType: selectedType!,
                                description: descriptionController.text.trim(),
                                location: location,
                              );
                              setModalState(
                                  () => _isReportingIncident = false);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                      child: _isReportingIncident
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Report incident',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (mounted) setState(() => _pendingIncidentLocation = null);
  }

  Future<void> _submitIncidentReport({
    required BusRoute route,
    required String incidentType,
    required String description,
    LatLng? location,
  }) async {
    try {
      double lat;
      double lng;
      if (location != null) {
        lat = location.latitude;
        lng = location.longitude;
      } else {
        final permission = await _resolveLocationPermission();
        if (!permission) {
          _showSnack('Location permission is needed to report an incident.', false);
          return;
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = position.latitude;
        lng = position.longitude;
      }
      await _fltsApiService.reportIncident(
        routeId: route.id,
        incidentType: incidentType,
        lat: lat,
        lng: lng,
        description: description,
      );
      await _pollIncidents(route.id);
      if (!mounted) return;
      _showSnack('Incident reported — thanks for the heads-up!', true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not report incident: $e', false);
    }
  }

  // ── Route selection ────────────────────────────────────────────────────────

  Future<void> _openRouteSelector() async {
    if (_isSharing) {
      await _gpsSharingService.stopSharing();
      setState(() => _isSharing = false);
    }
    _stopLiveListener();

    if (!mounted) return;
    final selected = await RouteSelectorSheet.show(context);
    if (selected == null) return;
    setState(() {
      _forwardRoute = selected;
      _isReversed = false;
      _selectedRoute = selected;
      _isPanelMinimized = false;
    });
    _startLiveListener(selected);
    _subscribeToRouteTopic(selected.id);
  }

  Future<void> _clearRoute() async {
    if (_isSharing) {
      await _gpsSharingService.stopSharing();
      setState(() => _isSharing = false);
    }
    _stopLiveListener();
    _unsubscribeFromCurrentRouteTopic();
    setState(() {
      _selectedRoute = null;
      _forwardRoute = null;
      _isReversed = false;
      _isPanelMinimized = false;
    });
  }

  /// Flips the selected route's direction, e.g. SLIIT Campus → Kaduwela
  /// becomes Kaduwela → SLIIT Campus. Always derived from [_forwardRoute] so
  /// toggling back and forth never accumulates extra "_return" suffixes.
  Future<void> _toggleDirection() async {
    final forward = _forwardRoute;
    if (forward == null) return;

    if (_isSharing) {
      await _gpsSharingService.stopSharing();
      _stopMyBusTracking();
      setState(() => _isSharing = false);
    }
    _stopLiveListener();

    final reversed = !_isReversed;
    final next = reversed ? forward.returnTrip : forward;
    setState(() {
      _isReversed = reversed;
      _selectedRoute = next;
    });
    _startLiveListener(next);
    _subscribeToRouteTopic(next.id);
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: Stack(
        children: [
          // ── Google Map — shows bus centroid marker only ─────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? _kSliitLocation,
              zoom: _kDefaultZoom,
            ),
            markers: {
              ..._markers,
              ..._routeEndMarkers,
              ..._myBusMarker,
              ..._buildIncidentMarkers(),
              if (_pendingIncidentLocation != null)
                Marker(
                  markerId: const MarkerId('pending_incident'),
                  position: _pendingIncidentLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRose,
                  ),
                  infoWindow: const InfoWindow(title: 'Marking incident here'),
                ),
            },
            polylines: _polylines,
            trafficEnabled: true,
            myLocationEnabled: !_isSharing,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onLongPress: _selectedRoute == null ? null : _handleMapLongPress,
          ),

          // ── App Bar ────────────────────────────────────────────
          SafeArea(
            child: _FltsAppBar(
              selectedRoute: _selectedRoute,
              isSharing: _isSharing,
              onBack: () => Navigator.of(context).pop(),
              onClearRoute: _clearRoute,
            ),
          ),

          // ── Bottom panel ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _selectedRoute == null
                  ? _SelectRoutePrompt(onTap: _openRouteSelector)
                  : _ActiveRoutePanel(
                      route: _selectedRoute!,
                      isSharing: _isSharing,
                      livePassengerCount: _livePassengerCount,
                      etaMinutes: _etaMinutes,
                      busSpeedKmh: _busSpeedKmh,
                      hasVehicleNumber: _hasVehicleNumber,
                      isMinimized: _isPanelMinimized,
                      onToggleMinimized: () => setState(
                        () => _isPanelMinimized = !_isPanelMinimized,
                      ),
                      onChangeRoute: _openRouteSelector,
                      onSwapDirection: _toggleDirection,
                      onToggleSharing: _toggleSharing,
                      onOpenFriendZone: () {
                        final route = _selectedRoute!;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FriendZoneScreen(route: route),
                          ),
                        );
                      },
                      onRateBus: () => _openFeedback(),
                    ),
            ),
          ),

          // ── Zoom controls ───────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedRoute == null ? 190 : 280,
            child: _ZoomControls(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),

          // ── Locate me FAB ──────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedRoute == null ? 130 : 220,
            child: _LocateFab(
              isLocating: _isLocating,
              onTap: _locateUser,
            ),
          ),

          // ── Report incident FAB ─────────────────────────────────
          if (_selectedRoute != null)
            Positioned(
              left: 16,
              bottom: 220,
              child: _ReportIncidentFab(onTap: _openReportIncidentSheet),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _FltsAppBar extends StatelessWidget {
  const _FltsAppBar({
    required this.selectedRoute,
    required this.isSharing,
    required this.onBack,
    required this.onClearRoute,
  });

  final BusRoute? selectedRoute;
  final bool isSharing;
  final VoidCallback onBack;
  final VoidCallback onClearRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _MapIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'FLTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Live Transit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  if (isSharing) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (selectedRoute != null)
                    GestureDetector(
                      onTap: onClearRoute,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select Route Prompt
// ─────────────────────────────────────────────────────────────────────────────

class _SelectRoutePrompt extends StatelessWidget {
  const _SelectRoutePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select your route',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap to choose your current bus route',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Color(0xFF9CA3AF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Route Panel
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveRoutePanel extends StatelessWidget {
  const _ActiveRoutePanel({
    required this.route,
    required this.isSharing,
    required this.livePassengerCount,
    required this.etaMinutes,
    this.busSpeedKmh,
    required this.hasVehicleNumber,
    required this.isMinimized,
    required this.onToggleMinimized,
    required this.onChangeRoute,
    required this.onSwapDirection,
    required this.onToggleSharing,
    required this.onOpenFriendZone,
    required this.onRateBus,
  });

  final BusRoute route;
  final bool isSharing;
  final int livePassengerCount;
  final Map<String, int?> etaMinutes;
  final double? busSpeedKmh;
  final bool hasVehicleNumber;
  final bool isMinimized;
  final VoidCallback onToggleMinimized;
  final VoidCallback onChangeRoute;
  final VoidCallback onSwapDirection;
  final VoidCallback onToggleSharing;
  final VoidCallback onOpenFriendZone;
  final VoidCallback onRateBus;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: EdgeInsets.fromLTRB(20, 10, 20, isMinimized ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle — tap to minimize/expand so the map is visible ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleMinimized,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          if (isMinimized)
            _MinimizedRouteBar(
              route: route,
              isSharing: isSharing,
              livePassengerCount: livePassengerCount,
              onToggleSharing: onToggleSharing,
              onExpand: onToggleMinimized,
            )
          else ...[
          // ── Route info row ─────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSharing
                      ? const Color(0xFFFFE4E4)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: isSharing
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF16A34A),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.origin}  →  ${route.destination}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // ── Real-time passenger count ──────────────
                    GestureDetector(
                      onTap: onOpenFriendZone,
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: livePassengerCount > 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD1D5DB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              livePassengerCount == 0
                                  ? 'No one sharing yet — be first!'
                                  : isSharing
                                      ? 'You + ${livePassengerCount - 1} others sharing · see FriendZone →'
                                      : '$livePassengerCount sharing live · see FriendZone →',
                              style: TextStyle(
                                fontSize: 12,
                                color: livePassengerCount > 0
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: livePassengerCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Swap direction',
                child: GestureDetector(
                  onTap: onSwapDirection,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      size: 18,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onChangeRoute,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Bus on map notice ──────────────────────────────────
          if (livePassengerCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Bus position shown on map — averaged from $livePassengerCount passenger${livePassengerCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (busSpeedKmh != null && busSpeedKmh! >= 2) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${busSpeedKmh!.round()} km/h',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── ETA strip ─────────────────────────────────────────
          if (route.stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            _EtaStrip(stops: route.stops, etaMinutes: etaMinutes),
          ],

          const SizedBox(height: 12),

          // ── Share / Stop button ────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isSharing
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF24AE59),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onToggleSharing,
              icon: Icon(
                isSharing
                    ? Icons.stop_circle_outlined
                    : Icons.near_me_rounded,
                size: 18,
              ),
              label: Text(isSharing ? 'Stop Sharing' : "I'm on this bus"),
            ),
          ),

          if (isSharing) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  'Only bus position shared — not your exact location',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],

          // ── Rate this bus button — only if a vehicle number is known ──
          // (yours, or picked up from another rider sharing the same bus)
          if (hasVehicleNumber) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRateBus,
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Rate this bus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFF16A34A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimized Route Bar
// ─────────────────────────────────────────────────────────────────────────────

class _MinimizedRouteBar extends StatelessWidget {
  const _MinimizedRouteBar({
    required this.route,
    required this.isSharing,
    required this.livePassengerCount,
    required this.onToggleSharing,
    required this.onExpand,
  });

  final BusRoute route;
  final bool isSharing;
  final int livePassengerCount;
  final VoidCallback onToggleSharing;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSharing
                  ? const Color(0xFFFFE4E4)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              color: isSharing
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF16A34A),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${route.origin}  →  ${route.destination}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  isSharing
                      ? 'Sharing · $livePassengerCount on this bus'
                      : livePassengerCount > 0
                          ? '$livePassengerCount sharing live'
                          : 'Tap to expand',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          if (isSharing)
            TextButton(
              onPressed: onToggleSharing,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                'Stop',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Color(0xFF9CA3AF),
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ETA Strip
// ─────────────────────────────────────────────────────────────────────────────

class _EtaStrip extends StatelessWidget {
  const _EtaStrip({required this.stops, required this.etaMinutes});

  final List<BusStop> stops;
  final Map<String, int?> etaMinutes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: stops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final stop = stops[i];
          final eta = etaMinutes[stop.id];
          final etaText = eta == null
              ? '—'
              : eta <= 0
                  ? 'Now'
                  : '${eta}m';
          final hasEta = eta != null && eta > 0;

          return Container(
            width: 90,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: hasEta ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasEta
                    ? const Color(0xFFFED7AA)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stop.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.directions_bus_rounded,
                      size: 10,
                      color: hasEta
                          ? const Color(0xFFEA580C)
                          : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      etaText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: hasEta
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zoom Controls
// ─────────────────────────────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onZoomIn,
            child: const SizedBox(
              width: 48,
              height: 44,
              child: Icon(
                Icons.add_rounded,
                color: Color(0xFF374151),
                size: 20,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          GestureDetector(
            onTap: onZoomOut,
            child: const SizedBox(
              width: 48,
              height: 44,
              child: Icon(
                Icons.remove_rounded,
                color: Color(0xFF374151),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Locate Me FAB
// ─────────────────────────────────────────────────────────────────────────────

class _LocateFab extends StatelessWidget {
  const _LocateFab({required this.isLocating, required this.onTap});

  final bool isLocating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocating ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: isLocating
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF24AE59),
                ),
              )
            : const Icon(
                Icons.my_location_rounded,
                color: Color(0xFF24AE59),
                size: 22,
              ),
      ),
    );
  }
}

class _ReportIncidentFab extends StatelessWidget {
  const _ReportIncidentFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Report an incident',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.report_gmailerrorred_rounded,
            color: Color(0xFFEF4444),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Icon Button
// ─────────────────────────────────────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF374151)),
      ),
    );
  }
}
