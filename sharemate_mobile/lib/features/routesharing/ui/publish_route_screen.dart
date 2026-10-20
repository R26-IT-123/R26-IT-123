import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../config/api_client.dart';
import '../services/routesharing_api_service.dart';
import 'widgets/location_autocomplete_field.dart';

class PublishRouteScreen extends StatefulWidget {
  const PublishRouteScreen({super.key});

  @override
  State<PublishRouteScreen> createState() => _PublishRouteScreenState();
}

class _PublishRouteScreenState extends State<PublishRouteScreen> {
  final _api = RouteSharingApiService();

  // Route details — auto-filled from profile
  final _destinationCtrl = TextEditingController();
  double? _destinationLat;
  double? _destinationLng;
  final _addressCtrl = TextEditingController();
  double? _pickupLat;
  double? _pickupLng;

  // Boarding stops
  final List<_StopEntry> _stops = [];

  // Schedule
  DateTime? _startDate;
  final _departureCtrl = TextEditingController(text: '07:00');

  // Vehicle & seats
  int _totalSeats = 3;

  bool _locating = false;
  bool _profileLoading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _addressCtrl.dispose();
    _departureCtrl.dispose();
    for (final s in _stops) { s.dispose(); }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.getDriverProfile();
      if (!mounted) return;
      setState(() {
        // Auto-fill destination from profile
        final dest = profile['regular_destination'] as String?;
        if (dest != null && dest.isNotEmpty) {
          _destinationCtrl.text = dest;
        }
        // Auto-fill start point from home_location
        final home = profile['home_location'] as Map<String, dynamic>?;
        if (home != null) {
          _pickupLat = (home['lat'] as num?)?.toDouble();
          _pickupLng = (home['lng'] as num?)?.toDouble();
          final addr = home['address'] as String?;
          if (addr != null && addr.isNotEmpty) {
            _addressCtrl.text = addr;
          }
        }
        _profileLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _locatePickup() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        if (mounted) {
          setState(() {
            _pickupLat = pos.latitude;
            _pickupLng = pos.longitude;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD97706)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final parts = _departureCtrl.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD97706)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _departureCtrl.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _submit() async {
    if (_destinationCtrl.text.trim().isEmpty) {
      _showError('Destination is required.');
      return;
    }
    if (_startDate == null) {
      _showError('Select a start date.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final waypoints = _stops
          .asMap()
          .entries
          .where((e) => e.value.ctrl.text.trim().isNotEmpty)
          .map((e) => {
                'address': e.value.ctrl.text.trim(),
                'order': e.key + 1,
                if (e.value.lat != null) 'lat': e.value.lat,
                if (e.value.lng != null) 'lng': e.value.lng,
              })
          .toList();

      final route = await _api.publishRoute(
        startLat: _pickupLat ?? 6.9155,
        startLng: _pickupLng ?? 79.9723,
        startAddress: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        destinationLat: _destinationLat,
        destinationLng: _destinationLng,
        startDate: _formatDate(_startDate!),
        departureTime: _departureCtrl.text.trim(),
        totalSeats: _totalSeats,
        waypoints: waypoints,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Route published! Price set to LKR ${route.pricePerTrip.toStringAsFixed(0)}/trip. All students will be notified.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Failed to publish route. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final endDate = _startDate?.add(const Duration(days: 7));

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
                  const Text(
                    'Publish Route',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            if (_profileLoading)
              const LinearProgressIndicator(
                color: Color(0xFFD97706),
                backgroundColor: Color(0xFFFEF3C7),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Route details ────────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle('Route details'),
                          const SizedBox(height: 16),
                          // Destination — autocomplete, lat/lng captured
                          LocationAutocompleteField(
                            controller: _destinationCtrl,
                            label: 'Destination',
                            hint: 'e.g. SLIIT Malabe',
                            icon: Icons.place_rounded,
                            onLocationSelected: (address, lat, lng) {
                              setState(() {
                                _destinationLat = lat;
                                _destinationLng = lng;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          // Pickup area — autocomplete, lat/lng captured
                          LocationAutocompleteField(
                            controller: _addressCtrl,
                            label: 'Start location',
                            hint: 'e.g. Kaduwela',
                            icon: Icons.home_rounded,
                            onLocationSelected: (address, lat, lng) {
                              setState(() {
                                _pickupLat = lat;
                                _pickupLng = lng;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          // Override GPS pin
                          OutlinedButton.icon(
                            onPressed: _locating ? null : _locatePickup,
                            icon: _locating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFD97706)))
                                : Icon(
                                    _pickupLat != null
                                        ? Icons.my_location_rounded
                                        : Icons.location_on_outlined,
                                    size: 16),
                            label: Text(
                              _pickupLat != null
                                  ? 'Start location pinned'
                                  : 'Pin my start location',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _pickupLat != null
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                              side: BorderSide(
                                  color: _pickupLat != null
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Boarding stops ────────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle('Boarding stops'),
                          const SizedBox(height: 4),
                          const Text(
                            'Add places along your route where passengers can board.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 14),
                          ..._stops.asMap().entries.map((entry) {
                            final i = entry.key;
                            final stop = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD97706),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LocationAutocompleteField(
                                      controller: stop.ctrl,
                                      label: 'Stop ${i + 1}',
                                      hint: 'e.g. Malabe Junction',
                                      icon: Icons.location_on_outlined,
                                      onLocationSelected: (address, lat, lng) {
                                        setState(() {
                                          stop.lat = lat;
                                          stop.lng = lng;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      stop.dispose();
                                      _stops.removeAt(i);
                                    }),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (_stops.length < 5)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _stops.add(_StopEntry())),
                              icon: const Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 16),
                              label: const Text('Add stop'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                padding: EdgeInsets.zero,
                                textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Schedule ─────────────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle('Schedule'),
                          const SizedBox(height: 16),
                          // Start date picker
                          GestureDetector(
                            onTap: _pickStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: _startDate != null
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 18, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Text(
                                    _startDate != null
                                        ? 'Start: ${_displayDate(_startDate!)}'
                                        : 'Select start date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _startDate != null
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (endDate != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_rounded,
                                      size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ends automatically: ${_displayDate(endDate)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          // Departure time
                          GestureDetector(
                            onTap: _pickTime,
                            child: AbsorbPointer(
                              child: _FormField(
                                controller: _departureCtrl,
                                label: 'Departure time',
                                hint: '07:00',
                                icon: Icons.access_time_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Vehicle & seats ──────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle('Vehicle & seats'),
                          const SizedBox(height: 16),
                          // Fixed: car only
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car_rounded,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Car',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text('Total seats',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280))),
                              const Spacer(),
                              _Counter(
                                value: _totalSeats,
                                min: 3,
                                max: 4,
                                onChanged: (v) =>
                                    setState(() => _totalSeats = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Publish button ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
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
                      : const Text('Publish Route'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StopEntry {
  _StopEntry() : ctrl = TextEditingController();
  final TextEditingController ctrl;
  double? lat;
  double? lng;
  void dispose() => ctrl.dispose();
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD97706)),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CounterBtn(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 12),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 12),
        _CounterBtn(
          icon: Icons.add_rounded,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _CounterBtn extends StatelessWidget {
  const _CounterBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null
              ? const Color(0xFFD97706)
              : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}
