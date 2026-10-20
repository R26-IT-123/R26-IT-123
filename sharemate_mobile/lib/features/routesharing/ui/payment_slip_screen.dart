import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/api_client.dart';
import '../models/booking.dart';
import '../services/routesharing_api_service.dart';

class PaymentSlipScreen extends StatefulWidget {
  const PaymentSlipScreen({
    super.key,
    required this.bookingId,
    required this.driverId,
  });
  final String bookingId;
  final String driverId;

  @override
  State<PaymentSlipScreen> createState() => _PaymentSlipScreenState();
}

class _PaymentSlipScreenState extends State<PaymentSlipScreen> {
  final _api = RouteSharingApiService();
  final _picker = ImagePicker();

  File? _pickedFile;
  PaymentSlip? _existingSlip;
  Map<String, dynamic>? _bankAccount;
  bool _loadingSlip = true;
  bool _loadingBankAccount = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
    _loadBankAccount();
  }

  Future<void> _loadExisting() async {
    try {
      final slip = await _api.getPaymentSlip(widget.bookingId);
      if (mounted) setState(() => _existingSlip = slip);
    } catch (_) {
      // no slip yet — that's fine
    } finally {
      if (mounted) setState(() => _loadingSlip = false);
    }
  }

  Future<void> _loadBankAccount() async {
    try {
      final account = await _api.getDriverBankAccount(widget.driverId);
      if (mounted) setState(() => _bankAccount = account);
    } catch (_) {
      // driver hasn't shared bank details — show fallback
    } finally {
      if (mounted) setState(() => _loadingBankAccount = false);
    }
  }

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_pickedFile == null) return;
    setState(() => _uploading = true);
    try {
      final url = await _api.uploadSlipToStorage(_pickedFile!, widget.bookingId);
      await _api.submitPaymentSlip(widget.bookingId, url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Payment slip submitted. Driver will verify soon.')),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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
                  const Text(
                    'Payment Slip',
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
              child: (_loadingSlip || _loadingBankAccount)
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ── Driver's account details ─────────
                          _DriverBankAccountCard(account: _bankAccount),
                          const SizedBox(height: 16),

                          // ── Existing slip ────────────────────
                          if (_existingSlip != null) ...[
                            _ExistingSlipCard(slip: _existingSlip!),
                            const SizedBox(height: 16),
                          ],

                          // ── Upload area ──────────────────────
                          if (_existingSlip == null ||
                              _existingSlip!.reviewStatus == 'rejected') ...[
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 220,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _pickedFile != null
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFE5E7EB),
                                    width: 2,
                                  ),
                                ),
                                child: _pickedFile != null
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        child: Image.file(
                                          _pickedFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                              Icons
                                                  .cloud_upload_outlined,
                                              size: 48,
                                              color: Color(0xFFD1D5DB)),
                                          SizedBox(height: 12),
                                          Text(
                                            'Tap to select payment slip image',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Upload a screenshot or photo of your bank transfer or mobile payment confirmation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),

            // ── Submit button ──────────────────────────────────────
            if (_existingSlip == null ||
                _existingSlip!.reviewStatus == 'rejected')
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        (_pickedFile == null || _uploading) ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Payment Slip'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverBankAccountCard extends StatelessWidget {
  const _DriverBankAccountCard({required this.account});
  final Map<String, dynamic>? account;

  @override
  Widget build(BuildContext context) {
    final holder = account?['bank_account_holder'] as String?;
    final bank = account?['bank_name'] as String?;
    final accountNumber = account?['bank_account_number'] as String?;
    final branch = account?['bank_branch'] as String?;
    final hasDetails = [holder, bank, accountNumber, branch]
        .any((v) => v != null && v.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              const Text(
                "Driver's Payment Account",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasDetails)
            const Text(
              "The driver hasn't added their bank details yet. Please contact them directly to arrange payment.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            )
          else ...[
            if (holder != null && holder.isNotEmpty)
              _AccountRow(label: 'Account holder', value: holder),
            if (bank != null && bank.isNotEmpty)
              _AccountRow(label: 'Bank', value: bank),
            if (accountNumber != null && accountNumber.isNotEmpty)
              _AccountRow(
                label: 'Account number',
                value: accountNumber,
                copyable: true,
              ),
            if (branch != null && branch.isNotEmpty)
              _AccountRow(label: 'Branch', value: branch),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account number copied.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Icon(Icons.copy_rounded,
                  size: 16, color: Color(0xFF9CA3AF)),
            ),
        ],
      ),
    );
  }
}

class _ExistingSlipCard extends StatelessWidget {
  const _ExistingSlipCard({required this.slip});
  final PaymentSlip slip;

  @override
  Widget build(BuildContext context) {
    final isApproved = slip.reviewStatus == 'approved';
    final isRejected = slip.reviewStatus == 'rejected';
    final color = isApproved
        ? const Color(0xFF16A34A)
        : isRejected
            ? const Color(0xFFEF4444)
            : const Color(0xFFD97706);
    final bgColor = isApproved
        ? const Color(0xFFF0FDF4)
        : isRejected
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFFEF3C7);
    final label = isApproved
        ? 'Verified'
        : isRejected
            ? 'Rejected'
            : 'Under Review';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved
                    ? Icons.verified_rounded
                    : isRejected
                        ? Icons.cancel_rounded
                        : Icons.hourglass_empty_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (slip.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${slip.rejectionReason}',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
