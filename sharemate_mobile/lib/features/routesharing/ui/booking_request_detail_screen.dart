import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../services/routesharing_api_service.dart';
import 'widgets/fare_breakdown_card.dart';

class BookingRequestDetailScreen extends StatefulWidget {
  const BookingRequestDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<BookingRequestDetailScreen> createState() =>
      _BookingRequestDetailScreenState();
}

class _BookingRequestDetailScreenState
    extends State<BookingRequestDetailScreen> {
  final _api = RouteSharingApiService();

  Booking? _booking;
  FareBreakdown? _fare;
  PaymentSlip? _slip;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await _api.getBooking(widget.bookingId);
      FareBreakdown? fare;
      PaymentSlip? slip;
      try {
        fare = await _api.getFareBreakdown(widget.bookingId);
      } catch (_) {}
      try {
        slip = await _api.getPaymentSlip(widget.bookingId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _booking = booking;
          _fare = fare;
          _slip = slip;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load booking.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      await _api.approveBooking(widget.bookingId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking approved!')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _decline() async {
    final reason = await _askReason();
    if (reason == null) return;
    setState(() => _acting = true);
    try {
      await _api.declineBooking(widget.bookingId,
          reason: reason.isEmpty ? null : reason);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking declined.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _requestPayment() async {
    setState(() => _acting = true);
    try {
      await _api.requestPayment(widget.bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Payment requested. Passenger will be notified to upload slip.')),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _verifySlip() async {
    setState(() => _acting = true);
    try {
      await _api.verifyPaymentSlip(widget.bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified. Seat confirmed!')),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _rejectSlip() async {
    final reason = await _askReason(
        hint: 'Reason for rejection (e.g. unclear image, wrong amount)');
    if (reason == null) return;
    setState(() => _acting = true);
    try {
      await _api.rejectPaymentSlip(
          widget.bookingId, reason.isEmpty ? 'Rejected' : reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Slip rejected. Passenger notified.')),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<String?> _askReason({String hint = 'Reason (optional)'}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add a note'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706)),
            child: const Text('Confirm'),
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
                    'Request Detail',
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
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)))
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280))))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _BookingInfoCard(booking: _booking!),
                              if (_fare != null) ...[
                                const SizedBox(height: 16),
                                FareBreakdownCard(fare: _fare!),
                              ],
                              if (_slip != null) ...[
                                const SizedBox(height: 16),
                                _SlipCard(
                                  slip: _slip!,
                                  onVerify:
                                      _slip!.reviewStatus == 'pending'
                                          ? _verifySlip
                                          : null,
                                  onReject:
                                      _slip!.reviewStatus == 'pending'
                                          ? _rejectSlip
                                          : null,
                                  acting: _acting,
                                ),
                              ],
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
            ),

            // ── Action bar ─────────────────────────────────────────
            if (!_loading && _booking != null)
              _ActionBar(
                booking: _booking!,
                acting: _acting,
                onApprove: _approve,
                onDecline: _decline,
                onRequestPayment: _requestPayment,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Booking info card ─────────────────────────────────────────────────────────

class _BookingInfoCard extends StatelessWidget {
  const _BookingInfoCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${booking.isWeekly ? "Weekly" : "Daily"} booking',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      _formatDays(booking.daysSelected),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 14),
          _Row(label: 'Booking ID', value: booking.id.substring(0, 8)),
          _Row(
              label: 'Fare',
              value:
                  'LKR ${booking.fareAmount.toStringAsFixed(0)}'),
          if (booking.seatNumber != null)
            _Row(
                label: 'Seat',
                value: '#${booking.seatNumber}'),
          if (booking.priority)
            const _Row(label: 'Priority', value: 'Yes (academic seniority)'),
        ],
      ),
    );
  }

  static String _formatDays(List<String> days) {
    if (days.length == 5) return 'Mon – Fri (full week)';
    return days
        .map((d) => d[0].toUpperCase() + d.substring(1, 3))
        .join(', ');
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280))),
          Text(value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              )),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    String label;
    switch (status) {
      case 'pending_approval':
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        label = 'Pending';
      case 'booking_approved':
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        label = 'Awaiting Payment';
      case 'payment_uploaded':
        color = const Color(0xFF7C3AED);
        bg = const Color(0xFFF5F3FF);
        label = 'Slip Uploaded';
      case 'confirmed':
        color = const Color(0xFF16A34A);
        bg = const Color(0xFFF0FDF4);
        label = 'Confirmed';
      case 'declined':
        color = const Color(0xFFEF4444);
        bg = const Color(0xFFFEF2F2);
        label = 'Declined';
      default:
        color = const Color(0xFF6B7280);
        bg = const Color(0xFFF3F4F6);
        label = status;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Slip card ─────────────────────────────────────────────────────────────────

class _SlipCard extends StatelessWidget {
  const _SlipCard({
    required this.slip,
    this.onVerify,
    this.onReject,
    required this.acting,
  });

  final PaymentSlip slip;
  final VoidCallback? onVerify;
  final VoidCallback? onReject;
  final bool acting;

  @override
  Widget build(BuildContext context) {
    final isPending = slip.reviewStatus == 'pending';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Slip',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              slip.slipImageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: const Color(0xFFF3F4F6),
                child: const Center(
                  child: Icon(Icons.broken_image_rounded,
                      size: 40, color: Color(0xFFD1D5DB)),
                ),
              ),
            ),
          ),
          if (isPending && (onVerify != null || onReject != null)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: acting ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: acting ? null : onVerify,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
          if (slip.reviewStatus == 'approved')
            _StatusPill(
                label: 'Verified',
                color: const Color(0xFF16A34A),
                bg: const Color(0xFFF0FDF4)),
          if (slip.reviewStatus == 'rejected')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(
                    label: 'Rejected',
                    color: const Color(0xFFEF4444),
                    bg: const Color(0xFFFEF2F2)),
                if (slip.rejectionReason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    slip.rejectionReason!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFEF4444)),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.booking,
    required this.acting,
    required this.onApprove,
    required this.onDecline,
    required this.onRequestPayment,
  });

  final Booking booking;
  final bool acting;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onRequestPayment;

  @override
  Widget build(BuildContext context) {
    // Step 1: Driver accepts or declines the booking request
    if (booking.status == 'pending_approval') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: acting ? null : onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Decline',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: acting ? null : onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: acting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Accept Booking'),
              ),
            ),
          ],
        ),
      );
    }

    // Waiting for passenger to upload payment slip
    if (booking.status == 'booking_approved') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty_rounded,
                  size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Waiting for passenger to upload payment slip',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Step 2: Slip uploaded — driver reviews via the slip card above
    if (booking.status == 'payment_uploaded') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 16, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Review the payment slip above to confirm seat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
