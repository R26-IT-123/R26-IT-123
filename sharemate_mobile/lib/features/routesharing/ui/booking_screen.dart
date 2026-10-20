import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../models/route_post.dart';
import '../services/routesharing_api_service.dart';
import 'widgets/day_selector.dart';
import 'widgets/fare_breakdown_card.dart';
import 'widgets/boarding_selector.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.route});
  final RoutePost route;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _api = RouteSharingApiService();

  late final List<RouteDateSlot> _dateSlots;
  late Set<String> _selectedDays;
  bool _addFriend = false;
  final _friendNameCtrl = TextEditingController();
  final _friendContactCtrl = TextEditingController();
  bool _submitting = false;

  // null = full route; non-null = selected waypoint stop
  Waypoint? _passengerStop;
  Waypoint? _friendStop;

  static const _weeklyDiscount = 0.17;
  static const _weekdayToKey = {
    1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu',
    5: 'fri', 6: 'sat', 7: 'sun',
  };
  static const _keyToName = {
    'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
    'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
  };

  @override
  void initState() {
    super.initState();
    _dateSlots = _buildDateSlots();
    _selectedDays = _dateSlots.map((s) => s.dayKey).toSet();
  }

  List<RouteDateSlot> _buildDateSlots() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    DateTime base;
    if (widget.route.startDate != null) {
      final parsed = DateTime.tryParse(widget.route.startDate!);
      base = (parsed != null && !parsed.isBefore(todayOnly)) ? parsed : todayOnly;
    } else {
      base = todayOnly;
    }

    final travelDays = widget.route.travelDays.toSet();
    final slots = <RouteDateSlot>[];
    for (var i = 0; i < 7; i++) {
      final date = base.add(Duration(days: i));
      final key = _weekdayToKey[date.weekday];
      if (key != null && travelDays.contains(key)) {
        slots.add(RouteDateSlot(
          dayKey: key,
          dayName: _keyToName[key]!,
          date: date,
        ));
      }
    }
    return slots;
  }

  @override
  void dispose() {
    _friendNameCtrl.dispose();
    _friendContactCtrl.dispose();
    super.dispose();
  }

  bool get _isWeekly =>
      _dateSlots.isNotEmpty && _selectedDays.length == _dateSlots.length;

  double _priceForStop(Waypoint? stop) {
    final stops = widget.route.waypoints;
    if (stop == null || stops.isEmpty) return widget.route.pricePerTrip;
    final remaining = stops.length + 1 - stop.order;
    return widget.route.pricePerTrip * remaining / (stops.length + 1);
  }

  String _boardingLabel(Waypoint? stop) =>
      stop == null ? 'Full route' : 'Stop ${stop.order}: ${stop.address}';

  FareBreakdown _computePreview() {
    final days = _selectedDays.length;
    final hasStops = widget.route.waypoints.isNotEmpty;

    final passengerPrice = _priceForStop(_passengerStop);
    final rawTotal = passengerPrice * days;
    final discountPct = _isWeekly ? _weeklyDiscount * 100 : 0.0;
    final discountAmt = _isWeekly ? rawTotal * _weeklyDiscount : 0.0;
    final total = rawTotal - discountAmt;

    double? friendTotal;
    double? combined;
    double? friendPricePerTrip;
    if (_addFriend) {
      final friendPrice = _priceForStop(_friendStop);
      final friendRaw = friendPrice * days;
      final friendDiscount = _isWeekly ? friendRaw * _weeklyDiscount : 0.0;
      friendTotal = friendRaw - friendDiscount;
      combined = total + friendTotal;
      friendPricePerTrip = friendPrice;
    }

    return FareBreakdown(
      pricePerTrip: passengerPrice,
      daysCount: days,
      bookingType: _isWeekly ? 'weekly' : 'daily',
      discountPct: discountPct,
      discountAmount: discountAmt,
      totalFare: total,
      paymentType: _isWeekly ? 'upfront' : 'post-ride',
      routeDistanceKm: widget.route.totalDistanceKm,
      pricePerKm: widget.route.pricePerKm,
      friendSeatSubtotal: friendTotal,
      combinedTotal: combined,
      passengerBoardingLabel: hasStops ? _boardingLabel(_passengerStop) : null,
      friendBoardingLabel: _addFriend && hasStops ? _boardingLabel(_friendStop) : null,
      friendPricePerTrip: friendPricePerTrip,
    );
  }

  Future<void> _confirm() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one travel day.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final booking = await _api.createBooking(
        routeId: widget.route.id,
        bookingType: _isWeekly ? 'weekly' : 'daily',
        daysSelected: _selectedDays.toList(),
        addFriendSeat: _addFriend,
        friendName:
            _friendNameCtrl.text.trim().isEmpty ? null : _friendNameCtrl.text.trim(),
        friendContact: _friendContactCtrl.text.trim().isEmpty
            ? null
            : _friendContactCtrl.text.trim(),
        pickupLat: _passengerStop?.lat,
        pickupLng: _passengerStop?.lng,
        pickupAddress: _passengerStop?.address,
        friendPickupLat: _addFriend ? _friendStop?.lat : null,
        friendPickupLng: _addFriend ? _friendStop?.lng : null,
        friendPickupAddress: _addFriend ? _friendStop?.address : null,
      );
      if (mounted) {
        _showSuccess(booking);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess(Booking booking) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 36, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Requested!',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              booking.isWeekly
                  ? 'Weekly booking placed. The driver will review and confirm soon. You\'ll need to pay upfront once confirmed.'
                  : 'Daily booking placed. The driver will confirm your seat. Pay after each ride.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // close the dialog
              Navigator.of(context).pop(); // close the booking screen
            },
            child: const Text('OK',
                style: TextStyle(color: Color(0xFFD97706))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final preview = _computePreview();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────
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
                  const Text(
                    'Book a Seat',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Route summary ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(Icons.directions_car_rounded,
                                color: Color(0xFFD97706), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route.destination,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  'Departs ${route.departureTime}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'LKR ${route.pricePerTrip.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Day selector ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select your travel days',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Only days this driver operates are selectable.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 16),
                          DaySelector(
                            slots: _dateSlots,
                            selected: _selectedDays,
                            onChanged: (days) =>
                                setState(() => _selectedDays = days),
                          ),
                          if (_isWeekly) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      size: 14, color: Color(0xFF16A34A)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Full week — 17% discount applied!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Boarding point ─────────────────────────────
                    if (widget.route.waypoints.isNotEmpty)
                      BoardingSelector(
                        title: 'Your boarding point',
                        waypoints: widget.route.waypoints,
                        selected: _passengerStop,
                        pricePerTrip: widget.route.pricePerTrip,
                        onChanged: (stop) =>
                            setState(() => _passengerStop = stop),
                      ),

                    if (widget.route.waypoints.isNotEmpty)
                      const SizedBox(height: 16),

                    // ── Add friend ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_rounded,
                                  size: 18, color: Color(0xFF6B7280)),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add a friend\'s seat',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      'Book two seats at once',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _addFriend,
                                onChanged: (v) =>
                                    setState(() => _addFriend = v),
                                activeColor: const Color(0xFFD97706),
                              ),
                            ],
                          ),
                          if (_addFriend) ...[
                            const SizedBox(height: 12),
                            _InputField(
                              controller: _friendNameCtrl,
                              label: 'Friend\'s name (optional)',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 10),
                            _InputField(
                              controller: _friendContactCtrl,
                              label: 'Friend\'s contact (optional)',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            if (widget.route.waypoints.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Divider(color: Color(0xFFF3F4F6)),
                              const SizedBox(height: 10),
                              BoardingSelector(
                                title: 'Friend\'s boarding point',
                                waypoints: widget.route.waypoints,
                                selected: _friendStop,
                                pricePerTrip: widget.route.pricePerTrip,
                                onChanged: (stop) =>
                                    setState(() => _friendStop = stop),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Fare preview ───────────────────────────────
                    if (_selectedDays.isNotEmpty) FareBreakdownCard(fare: preview),

                    const SizedBox(height: 16),

                    // ── Booking type info ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isWeekly
                                  ? 'Weekly booking: You\'ll pay upfront after driver approval. Upload your payment slip to confirm your seat.'
                                  : 'Daily booking: Pay the driver in cash or mobile after each trip.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Confirm button ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_submitting || _selectedDays.isEmpty) ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _selectedDays.isEmpty
                              ? 'Select travel days'
                              : 'Confirm Booking',
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

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }
}
