import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../features/flts/models/bus_route.dart';
import '../features/grocery/models/trust_profile.dart';
import '../features/grocery/services/grocery_api_service.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedRouteId;
  bool _isSaving = false;
  bool _saved = false;
  bool _isLoadingRoute = true;
  String? _currentPhotoUrl;
  bool _isUploadingPhoto = false;
  String? _savedRouteId;
  TrustProfile? _trustProfile;
  bool _loadingTrust = true;
  final UserProfileService _userProfileService = UserProfileService();
  final GroceryApiService _groceryService = GroceryApiService();

  @override
  void initState() {
    super.initState();
    _selectedRouteId = widget.profile.preferredRouteId;
    _savedRouteId = widget.profile.preferredRouteId;
    _currentPhotoUrl = widget.profile.photoUrl;
    _loadRouteFromFirestore();
    _loadTrustProfile();
  }

  Future<void> _loadTrustProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingTrust = false);
      return;
    }
    try {
      final profile = await _groceryService.getTrustProfile(uid);
      if (mounted) setState(() { _trustProfile = profile; _loadingTrust = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTrust = false);
    }
  }

  Future<void> _loadRouteFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingRoute = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      final routeId = doc.data()?['preferred_route_id'] as String?;
      setState(() {
        _selectedRouteId = routeId;
        _isLoadingRoute = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _saveRoute() async {
    setState(() => _isSaving = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null || token.isEmpty) throw Exception('Not signed in.');

      await _userProfileService.updateProfile(
        idToken: token,
        preferredRouteId: _selectedRouteId,
      );

      // Keep FCM topic subscription in sync with the saved route.
      final oldRoute = _savedRouteId;
      final newRoute = _selectedRouteId;
      if (oldRoute != null && oldRoute != newRoute) {
        await FirebaseMessaging.instance
            .unsubscribeFromTopic('flts_route_$oldRoute');
      }
      if (newRoute != null && newRoute != oldRoute) {
        await FirebaseMessaging.instance
            .subscribeToTopic('flts_route_$newRoute');
      }

      setState(() {
        _saved = true;
        _savedRouteId = newRoute;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preferred route saved!'),
            backgroundColor: const Color(0xFF24AE59),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null || token.isEmpty) throw Exception('Not signed in.');

      final photoUrl = await _userProfileService.uploadPhoto(
        idToken: token,
        filePath: picked.path,
      );
      setState(() => _currentPhotoUrl = photoUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  String get _initials {
    final parts = widget.profile.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.profile.fullName.isNotEmpty
        ? widget.profile.fullName[0].toUpperCase()
        : 'S';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF111827),
          ),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name card ─────────────────────────────────
            _AvatarCard(
              initials: _initials,
              profile: widget.profile,
              photoUrl: _currentPhotoUrl,
              onUploadPhoto: _pickAndUploadPhoto,
              isUploading: _isUploadingPhoto,
            ),
            const SizedBox(height: 16),

            // ── Info card ──────────────────────────────────────────
            _InfoCard(profile: widget.profile),
            const SizedBox(height: 20),

            // ── Grocery trust score ────────────────────────────────
            _TrustAnalyticsCard(
              profile: _trustProfile,
              loading: _loadingTrust,
            ),
            const SizedBox(height: 20),

            // ── Route preference ───────────────────────────────────
            Row(
              children: [
                _sectionLabel('My Usual Bus Route'),
                if (_isLoadingRoute) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF24AE59),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select the route you travel most. This personalises your home screen and auto-selects your route on the Live Transit map.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            // No preference option
            _RouteOption(
              label: 'No preference',
              subtitle: 'I will select manually each time',
              icon: Icons.close_rounded,
              isSelected: _selectedRouteId == null,
              onTap: () => setState(() {
                _selectedRouteId = null;
                _saved = false;
              }),
            ),
            const SizedBox(height: 8),

            // Route options
            ...BusRoute.sliitRoutes.map((route) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RouteOption(
                    label: route.displayName,
                    subtitle: 'SLIIT commuter route',
                    icon: Icons.directions_bus_rounded,
                    isSelected: _selectedRouteId == route.id,
                    onTap: () => setState(() {
                      _selectedRouteId = route.id;
                      _saved = false;
                    }),
                  ),
                )),

            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _saved
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF24AE59),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _isSaving || _saved ? null : _saveRoute,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_saved ? 'Saved ✓' : 'Save Route Preference'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Card
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.initials,
    required this.profile,
    this.photoUrl,
    this.onUploadPhoto,
    this.isUploading = false,
  });

  final String initials;
  final UserProfile profile;
  final String? photoUrl;
  final VoidCallback? onUploadPhoto;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onUploadPhoto,
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: photoUrl == null
                        ? const LinearGradient(
                            colors: [Color(0xFF24AE59), Color(0xFF0E6B35)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            photoUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF24AE59),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isUploading
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.universityEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SLIIT Student',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Student ID',
            value: profile.studentId,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.school_outlined,
            label: 'Faculty',
            value: profile.faculty,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Academic Year',
            value: profile.academicYear,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: profile.mobileNumber,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Color(0xFFF3F4F6), thickness: 1, height: 1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trust Analytics Card
// ─────────────────────────────────────────────────────────────────────────────

class _TrustAnalyticsCard extends StatelessWidget {
  const _TrustAnalyticsCard({required this.profile, required this.loading});

  final TrustProfile? profile;
  final bool loading;

  static const _accent = Color(0xFFBE185D);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: _accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grocery Trust Score',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  Text(
                    'Based on peer feedback from completed trips',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
              ),
            )
          else if (profile == null || !profile!.hasAnyData)
            _buildEmpty()
          else
            _buildData(profile!),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.star_outline_rounded, color: Color(0xFFD1D5DB), size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No activity yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
                SizedBox(height: 3),
                Text(
                  'Complete grocery trips to build your trust profile.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(TrustProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Overall score + completed trips ──────────────────────────
        Row(
          children: [
            // Big overall score
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.totalRatings > 0 ? p.avgRating.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        height: 1,
                      ),
                    ),
                    if (p.totalRatings > 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6, left: 3),
                        child: Text(
                          '/ 5',
                          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (p.totalRatings > 0)
                  _StarRow(rating: p.avgRating)
                else
                  const Text('No ratings yet', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 3),
                Text(
                  '${p.totalRatings} ${p.totalRatings == 1 ? 'rating' : 'ratings'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),

            const Spacer(),

            // Completed trips pill
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${p.completedTrips}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0369A1),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'trips done',
                        style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Split scores: As Shopper / As Requester ───────────────────
        if (p.shopperCount > 0 || p.requesterCount > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (p.shopperCount > 0)
                Expanded(
                  child: _SplitScoreChip(
                    label: 'As Shopper',
                    icon: Icons.shopping_cart_rounded,
                    avg: p.shopperAvg,
                    count: p.shopperCount,
                    color: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFEDE9FE),
                  ),
                ),
              if (p.shopperCount > 0 && p.requesterCount > 0)
                const SizedBox(width: 10),
              if (p.requesterCount > 0)
                Expanded(
                  child: _SplitScoreChip(
                    label: 'As Requester',
                    icon: Icons.shopping_basket_rounded,
                    avg: p.requesterAvg,
                    count: p.requesterCount,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFD1FAE5),
                  ),
                ),
            ],
          ),
        ],

        // ── Badges ───────────────────────────────────────────────────
        if (p.badges.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Earned badges',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.badges.map((b) => _BadgeChip(badge: b)).toList(),
          ),
        ],

        // ── Bar chart ────────────────────────────────────────────────
        if (p.recentRatings.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Rating trend',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
              const SizedBox(width: 6),
              Text(
                '(last ${p.recentRatings.length} trips)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TrustBarChart(ratings: p.recentRatings),
        ],

        // ── Recent comments ──────────────────────────────────────────
        if (p.recentRatings.any((r) => r.comment.isNotEmpty)) ...[
          const SizedBox(height: 20),
          const Text(
            'What peers say',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          ...p.recentRatings
              .where((r) => r.comment.isNotEmpty)
              .take(3)
              .map((r) => _TrustComment(rating: r)),
        ],
      ],
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
        i < rating.floor()
            ? Icons.star_rounded
            : (i < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
        color: const Color(0xFFF59E0B),
        size: 16,
      )),
    );
  }
}

class _SplitScoreChip extends StatelessWidget {
  const _SplitScoreChip({
    required this.label,
    required this.icon,
    required this.avg,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final IconData icon;
  final double avg;
  final int count;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            avg.toStringAsFixed(1),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, height: 1),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 11, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 2),
              Text(
                '$count ${count == 1 ? 'rating' : 'ratings'}',
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});
  final String badge;

  static const _badges = {
    'reliable_shopper': (
      icon: Icons.local_shipping_rounded,
      label: 'Reliable Shopper',
      color: Color(0xFF059669),
      bg: Color(0xFFD1FAE5),
    ),
    'trusted_payer': (
      icon: Icons.payments_rounded,
      label: 'Trusted Payer',
      color: Color(0xFF0369A1),
      bg: Color(0xFFE0F2FE),
    ),
    'community_helper': (
      icon: Icons.volunteer_activism_rounded,
      label: 'Community Helper',
      color: Color(0xFF7C3AED),
      bg: Color(0xFFEDE9FE),
    ),
    'top_rated': (
      icon: Icons.workspace_premium_rounded,
      label: 'Top Rated',
      color: Color(0xFFB45309),
      bg: Color(0xFFFEF3C7),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _badges[badge];
    if (meta == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13, color: meta.color),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: meta.color),
          ),
        ],
      ),
    );
  }
}

class _TrustBarChart extends StatelessWidget {
  const _TrustBarChart({required this.ratings});
  final List<TrustRating> ratings;

  static const _gold   = Color(0xFFF59E0B);
  static const _accent = Color(0xFFBE185D);

  @override
  Widget build(BuildContext context) {
    final ordered = ratings.reversed.toList();
    const maxH = 60.0;

    return Column(
      children: [
        SizedBox(
          height: maxH + 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ordered.asMap().entries.map((e) {
              final isNewest = e.key == ordered.length - 1;
              final barH = (e.value.rating / 5) * maxH;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${e.value.rating}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isNewest ? _accent : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    width: 20,
                    height: barH.clamp(5.0, maxH),
                    decoration: BoxDecoration(
                      color: isNewest ? _accent : _gold.withValues(alpha: 0.55 + e.key * 0.045),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Oldest', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            Text('Newest', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }
}

class _TrustComment extends StatelessWidget {
  const _TrustComment({required this.rating});
  final TrustRating rating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(5, (i) => Icon(
                i < rating.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B),
                size: 13,
              )),
            ),
            const SizedBox(height: 5),
            Text(
              rating.comment,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route Option Card
// ─────────────────────────────────────────────────────────────────────────────

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF0FDF4)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF24AE59)
                : const Color(0xFFF3F4F6),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF111827)
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF24AE59),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
