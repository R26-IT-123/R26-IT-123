import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/places_service.dart';

class LocationAutocompleteField extends StatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.onLocationSelected,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  /// Called after the user picks a suggestion and the Place Details are
  /// fetched. Pass null to skip the Details API call (text-only fields).
  final void Function(String address, double lat, double lng)? onLocationSelected;

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final _focusNode = FocusNode();
  List<PlacePrediction> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay so a tap on a suggestion registers before hiding the list.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _suggestions = []);
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final results = await PlacesService.autocomplete(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  Future<void> _onSelect(PlacePrediction prediction) async {
    widget.controller.text = prediction.description;
    setState(() { _suggestions = []; _searching = false; });
    _focusNode.unfocus();

    if (widget.onLocationSelected == null) return;
    final detail = await PlacesService.getDetail(prediction.placeId);
    if (detail != null && mounted) {
      widget.onLocationSelected!(detail.address, detail.lat, detail.lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle:
                const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
            prefixIcon:
                Icon(widget.icon, size: 18, color: const Color(0xFF9CA3AF)),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFD97706)),
                    ),
                  )
                : null,
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
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: i == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: i == (_suggestions.length - 1).clamp(0, 4)
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                  onTap: () => _onSelect(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.description,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF374151)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
