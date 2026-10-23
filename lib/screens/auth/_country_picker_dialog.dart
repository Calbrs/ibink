import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:world_code_picker/country_code_picker.dart';

/// Bottom-aligned country picker: a dark ink panel with gold text.
/// The selected country is full gold + bold + check; the rest are
/// slightly softer gold.
import 'auth_screen.dart';

class CountryPickerDialog extends StatefulWidget {
  final List<Country> countries;
  final Country selected;

  const CountryPickerDialog({
    super.key,
    required this.countries,
    required this.selected,
  });

  @override
  State<CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<CountryPickerDialog> {
  late List<Country> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.countries);
    _searchController.addListener(_filter);
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.countries
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.dialCode.contains(q) ||
                c.isoCode.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = math.max(
      240.0,
      math.min(
        mq.size.height * 0.64,
        mq.size.height - mq.viewInsets.bottom - 96,
      ),
    );
    final query = _searchController.text.trim();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          // Same pastel wash as the auth screens: lavender → peach over white.
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Same wash colors as the auth screens, opaque (composited
              // once over white): lavender #E2DCF5 → peach #FFE0CA.
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFFE2DCF5), Color(0xFFFFE0CA)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AuthColors.gold.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select country',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          InkResponse(
                            onTap: () => Navigator.of(context).pop(),
                            radius: 22,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: AuthGlyph(
                                AuthGlyphType.close,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AuthDarkField(
                        controller: _searchController,
                        hint: 'Search country',
                        search: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  'No country matches "$query".',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) {
                                final c = _filtered[i];
                                final isSelected =
                                    c.isoCode == widget.selected.isoCode;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(ctx).pop(c),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          c.flagEmoji,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.black.withValues(
                                                      alpha: 0.85,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          c.dialCode,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.black.withValues(
                                                    alpha: 0.7,
                                                  ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 28,
                                          child: isSelected
                                              ? const Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: AuthGlyph(
                                                    AuthGlyphType.check,
                                                    color: Colors.black,
                                                    size: 18,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
