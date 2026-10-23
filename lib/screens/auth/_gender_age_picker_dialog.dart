import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_screen.dart';

/// Gender + date-of-birth selector cards. Same bottom-aligned "modal card"
/// as the country picker — pastel wash (lavender → peach) over white, drag
/// handle, close glyph, selected row bold with a check — but hand-built,
/// no stock Material widgets.
///
/// [GenderPickerDialog] is a short option list; [AgePickerDialog] is a
/// triple date-of-birth wheel (day · month · year) with a white "lens"
/// band and an ink confirm pill. Age is derived from the chosen date.

/// Shared scaffolding for both cards: drag handle + header row + content.
class _CardShell extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  const _CardShell({
    required this.title,
    required this.child,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        // Same wash colors as the auth screens, opaque (composited once
        // over white): lavender #E2DCF5 → peach #FFE0CA.
        child: DecoratedBox(
          decoration: BoxDecoration(
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
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
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
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------- gender ----------------------------

/// The three gender options shown in the picker.
const List<String> kGenderOptions = ['Male', 'Female', 'Other'];

class GenderPickerDialog extends StatelessWidget {
  /// Currently selected option (may be null — nothing pre-selected).
  final String? selected;

  const GenderPickerDialog({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Select gender',
      height: 300,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          for (final gender in kGenderOptions)
            _OptionRow(
              label: gender,
              selected: gender == selected,
              onTap: () => Navigator.of(context).pop(gender),
            ),
        ],
      ),
    );
  }
}

/// One tappable row: bold black label when selected, check at the end —
/// the country-picker row model (no flags/dial code).
class _OptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.black
                      : Colors.black.withValues(alpha: 0.85),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: selected
                  ? const Align(
                      alignment: Alignment.centerRight,
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
  }
}

// ---------------------------- date of birth ----------------------------

const List<String> _kMonthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Triple date-of-birth wheel (day · month · year) inside the same card:
/// a full-width white "lens" band over the centred rows, hairlines
/// above/below, faded edges, and an ink confirm pill. Popping returns the
/// computed age in whole years (null-safe via widgets above).
class AgePickerDialog extends StatefulWidget {
  /// Previously entered age, used to spin the year wheel near the right
  /// spot when reopened (may be null — defaults to 25 years ago).
  final int? selected;

  const AgePickerDialog({super.key, this.selected});

  @override
  State<AgePickerDialog> createState() => _AgePickerDialogState();
}

class _AgePickerDialogState extends State<AgePickerDialog> {
  static const _startYear = 1940;

  final DateTime _now = DateTime.now();

  late int _day;
  late int _month; // 1..12
  late int _year;

  late final FixedExtentScrollController _dayWheel;
  late final FixedExtentScrollController _monthWheel;
  late final FixedExtentScrollController _yearWheel;

  @override
  void initState() {
    super.initState();
    final priorAge = widget.selected;
    final sameDayAsToday = DateTime.now();
    _year = (priorAge != null && priorAge >= 1 && priorAge <= 120)
        ? sameDayAsToday.year - priorAge
        : sameDayAsToday.year - 25;
    _month = sameDayAsToday.month;
    _day = math.min(sameDayAsToday.day, _daysIn(_month, _year));

    _dayWheel = FixedExtentScrollController(initialItem: _day - 1);
    _monthWheel = FixedExtentScrollController(initialItem: _month - 1);
    _yearWheel = FixedExtentScrollController(
      initialItem: (_year - _startYear).clamp(
        0,
        sameDayAsToday.year - _startYear,
      ),
    );
  }

  @override
  void dispose() {
    _dayWheel.dispose();
    _monthWheel.dispose();
    _yearWheel.dispose();
    super.dispose();
  }

  bool _isLeap(int y) => (y % 4 == 0) && (y % 100 != 0 || y % 400 == 0);

  int _daysIn(int month, int year) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeap(year)) return 29;
    return lengths[month - 1];
  }

  /// Age derived from the selected date of birth (null when the date
  /// would be invalid — i.e. younger than 1 whole year).
  int? get _computedAge {
    var age = _now.year - _year;
    if (_now.month < _month || (_now.month == _month && _now.day < _day)) {
      age--;
    }
    if (age < 1 || age > 120) return null;
    return age;
  }

  void _onDayChanged(int index) => setState(() => _day = (index % 31) + 1);

  void _onMonthChanged(int index) {
    setState(() {
      _month = (index % 12) + 1;
      _clampDay();
    });
  }

  void _onYearChanged(int index) {
    setState(() {
      _year = _startYear + (index % _yearCount);
      _clampDay();
    });
  }

  /// Years available on the wheel: 1940 … today.
  int get _yearCount => _now.year - _startYear + 1;

  static Widget _wheelLabel(bool selected, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: selected ? 22 : 18,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? Colors.black : Colors.black.withValues(alpha: 0.75),
      ),
    );
  }

  /// Shorten long months/years: 31 in February etc. The day wheel is
  /// pulled back to the last valid day for the newly selected month/year.
  void _clampDay() {
    final maxDay = _daysIn(_month, _year);
    if (_day <= maxDay) return;
    setState(() {
      _day = maxDay;
      _dayWheel.animateToItem(
        maxDay - 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final age = _computedAge;
    final canConfirm = age != null;

    return _CardShell(
      title: 'Date of birth',
      height: 380,
      child: Column(
        children: [
          // ---------- wheels with white lens band ----------
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Lens band: hairline / white pill / hairline, stretched
                // across the card so it lines up with the centre rows.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hairline(),
                      Container(
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x221D1507),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      _hairline(),
                    ],
                  ),
                ),
                // The three wheels, edges faded by one shared mask.
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.22, 0.78, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white,
                      Colors.white,
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _wheelMini(
                        width: 62,
                        controller: _dayWheel,
                        itemCount: 31,
                        onSelectedItemChanged: _onDayChanged,
                        builder: (i) => Center(
                          child: _wheelLabel(_day == i + 1, '${i + 1}'),
                        ),
                      ),
                      _wheelMini(
                        width: 94,
                        controller: _monthWheel,
                        itemCount: 12,
                        onSelectedItemChanged: _onMonthChanged,
                        builder: (i) => Center(
                          child: _wheelLabel(_month == i + 1, _kMonthLabels[i]),
                        ),
                      ),
                      _wheelMini(
                        width: 96,
                        controller: _yearWheel,
                        itemCount: _yearCount,
                        onSelectedItemChanged: _onYearChanged,
                        builder: (i) => Center(
                          child: _wheelLabel(
                            _year == _startYear + i,
                            '${_startYear + i}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- confirm ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: Opacity(
                opacity: canConfirm ? 1 : 0.45,
                child: Material(
                  color: AuthColors.ink,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: canConfirm
                        ? () => Navigator.of(context).pop(age)
                        : null,
                    splashColor: AuthColors.gold.withValues(alpha: 0.18),
                    child: Center(
                      child: Text(
                        canConfirm ? 'Set age' : 'Pick a valid date',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                          color: AuthColors.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One wheel column: fixed width so the three sit tight and centred.
  Widget _wheelMini({
    required double width,
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required Widget Function(int index) builder,
  }) {
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 52,
        perspective: 0.0015,
        diameterRatio: 8,
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.45,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: List.generate(itemCount, builder),
        ),
        onSelectedItemChanged: onSelectedItemChanged,
      ),
    );
  }

  /// Thin hairline capping the lens band top/bottom (full row width).
  static Widget _hairline() {
    return Container(height: 1, color: Colors.black.withValues(alpha: 0.12));
  }
}
