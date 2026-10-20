import 'package:flutter/material.dart';

import '../../../config/api_client.dart';
import '../services/routesharing_api_service.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _api = RouteSharingApiService();
  final _formKey = GlobalKey<FormState>();

  final _holderController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _hasExisting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _holderController.dispose();
    _bankController.dispose();
    _accountNumberController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.getDriverProfile();
      final holder = profile['bank_account_holder'] as String?;
      final bank = profile['bank_name'] as String?;
      final accountNumber = profile['bank_account_number'] as String?;
      final branch = profile['bank_branch'] as String?;
      _holderController.text = holder ?? '';
      _bankController.text = bank ?? '';
      _accountNumberController.text = accountNumber ?? '';
      _branchController.text = branch ?? '';
      if (mounted) {
        setState(() {
          _hasExisting = [holder, bank, accountNumber, branch]
              .any((v) => v != null && v.isNotEmpty);
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load account details.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.updateDriverProfile({
        'bank_account_holder': _holderController.text.trim(),
        'bank_name': _bankController.text.trim(),
        'bank_account_number': _accountNumberController.text.trim(),
        'bank_branch': _branchController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasExisting
                ? 'Account details updated.'
                : 'Account details saved.'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save account details.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
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
                  Text(
                    _hasExisting ? 'Edit Account Details' : 'Add Account Details',
                    style: const TextStyle(
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
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'These bank details are used so passengers know where to send payment for your rides.',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 20),
                                _FieldLabel('Account holder name'),
                                TextFormField(
                                  controller: _holderController,
                                  decoration: _inputDecoration('e.g. A. B. Perera'),
                                  validator: _requiredValidator,
                                ),
                                const SizedBox(height: 16),
                                _FieldLabel('Bank name'),
                                TextFormField(
                                  controller: _bankController,
                                  decoration: _inputDecoration('e.g. Commercial Bank'),
                                  validator: _requiredValidator,
                                ),
                                const SizedBox(height: 16),
                                _FieldLabel('Account number'),
                                TextFormField(
                                  controller: _accountNumberController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('e.g. 8001234567'),
                                  validator: _requiredValidator,
                                ),
                                const SizedBox(height: 16),
                                _FieldLabel('Branch'),
                                TextFormField(
                                  controller: _branchController,
                                  decoration: _inputDecoration('e.g. Colombo 03'),
                                  validator: _requiredValidator,
                                ),
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
            ),

            // ── Save button ──────────────────────────────────────
            if (!_loading && _error == null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_hasExisting ? 'Save Changes' : 'Save Account Details'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
