import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_screen.dart';
import 'phone_screen.dart';
import '_gender_age_picker_dialog.dart';

/// Register form — same visual language as the phone screen: white pills
/// (56px, radius 999), the phone number reuses the exact phone-bar module
/// (country chip + digits), and the last action is the ink pill.
/// No logo, no social buttons — the screen stays light and airy.
///
/// Keyboard behaviour: the focused field that the keyboard would cover
/// floats [kFieldFloatGap] above it (Transform only — the rest of the
/// form stays exactly where it is), and settles back when the keyboard
/// closes. Both directions animate.
///
/// Field order: first name → middle name → last name → gender → age →
/// phone number → email. The email is prefilled from the phone screen;
/// the backend requires first/last name.
class RegisterScreen extends StatefulWidget {
  final AuthController controller;

  /// Opens the country picker (owned by [AuthScreen]).
  final VoidCallback onPickCountry;

  const RegisterScreen({
    super.key,
    required this.controller,
    required this.onPickCountry,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameFocus = FocusNode();
  final _middleNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _middleNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    // Keyboard edge: distance from the top of the screen to the top of
    // the keyboard (inset 0 while the keyboard is closed).
    final mq = MediaQuery.of(context);
    final keyboardVisible = mq.viewInsets.bottom > 0;
    final double? keyboardTop = keyboardVisible
        ? mq.size.height - mq.viewInsets.bottom
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Push the content down so it sits against the bottom of the
        // screen (the shell contributes 20px + this 20px = 40px gap).
        const Spacer(),

        // ---------- Header (bigger + extra bold) ----------
        AuthHeading(
          title: 'Register',
          subtitle: 'Tell us a bit about yourself.',
          titleSize: 46,
          titleWeight: FontWeight.w900,
          subtitleSize: 18,
        ),
        const SizedBox(height: 20),

        AuthErrorBanner(c.errorMsg),
        const SizedBox(height: 8),

        // ---------- Fields (vertical, ordered) ----------
        _FieldLift(
          focusNode: _firstNameFocus,
          keyboardTop: keyboardTop,
          child: _RegisterField(
            controller: c.firstNameController,
            hint: 'First name',
            focusNode: _firstNameFocus,
          ),
        ),
        const SizedBox(height: 12),
        _FieldLift(
          focusNode: _middleNameFocus,
          keyboardTop: keyboardTop,
          child: _RegisterField(
            controller: c.middleNameController,
            hint: 'Middle name (optional)',
            focusNode: _middleNameFocus,
          ),
        ),
        const SizedBox(height: 12),
        _FieldLift(
          focusNode: _lastNameFocus,
          keyboardTop: keyboardTop,
          child: _RegisterField(
            controller: c.lastNameController,
            hint: 'Last name',
            focusNode: _lastNameFocus,
          ),
        ),
        const SizedBox(height: 12),

        // Gender — picker card (same modal as the country picker).
        _PickerPill(
          label: c.gender,
          hint: 'Gender',
          onTap: () => _pickGender(context, c),
        ),
        const SizedBox(height: 12),

        // Age — spinning wheel picker card.
        _PickerPill(
          label: c.ageController.text.isEmpty
              ? null
              : '${c.ageController.text} years',
          hint: 'Age',
          onTap: () => _pickAge(context, c),
        ),
        const SizedBox(height: 12),

        // Phone bar (same module as the phone screen).
        _FieldLift(
          focusNode: _phoneFocus,
          keyboardTop: keyboardTop,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: _kControlHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthCountryChip(
                    isoCode: c.selectedCountry.isoCode,
                    dialCode: c.selectedCountry.dialCode,
                    onTap: widget.onPickCountry,
                  ),
                  Expanded(
                    child: _PillTextField(
                      controller: c.registerPhoneController,
                      hint: '712 345 678',
                      keyboardType: TextInputType.phone,
                      focusNode: _phoneFocus,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onChanged: (v) {
                        if (v.startsWith('0')) {
                          final stripped = v.replaceFirst(RegExp(r'^0+'), '');
                          c.registerPhoneController.value = TextEditingValue(
                            text: stripped,
                            selection: TextSelection.collapsed(
                              offset: stripped.length,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Email (prefilled from the phone screen) — last by design.
        _FieldLift(
          focusNode: _emailFocus,
          keyboardTop: keyboardTop,
          child: _RegisterField(
            controller: c.emailController,
            hint: 'Email address',
            focusNode: _emailFocus,
          ),
        ),

        const SizedBox(height: 20),

        // ---------- Complete registration ----------
        _RegisterButton(
          label: 'Complete registration',
          loading: c.isLoading,
          onPressed: c.register,
        ),

        // 40px total from the screen bottom (20px extra on top of the
        // shell's 20px bottom padding).
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------------------- keyboard float ----------------------------

/// Gap between a floating field's bottom edge and the keyboard's top edge.
const double kFieldFloatGap = 20;

/// One shared animation curve for float/scale/border transitions.
const Duration kFieldFloatDuration = Duration(milliseconds: 260);

/// Paints its child [kFieldFloatGap] above the keyboard when the keyboard
/// would cover the focused field. The offset is Transform-only: nothing
/// else in the form shifts, and the field floats back down (animated)
/// when the keyboard dismisses or focus moves away.
class _FieldLift extends StatefulWidget {
  final FocusNode focusNode;

  /// Dotted y coordinate of the keyboard's top edge, or null while the
  /// keyboard is closed.
  final double? keyboardTop;
  final Widget child;

  const _FieldLift({
    required this.focusNode,
    required this.keyboardTop,
    required this.child,
  });

  @override
  State<_FieldLift> createState() => _FieldLiftState();
}

class _FieldLiftState extends State<_FieldLift> {
  /// Target translation (negative dy). 0 = normal position.
  double _target = 0;

  /// Bottom edge of the child measured before any float is applied —
  /// cached once so the animating transform never feeds back into the
  /// measurement.
  double? _baseBottom;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _FieldLift old) {
    super.didUpdateWidget(old);
    if (old.keyboardTop != widget.keyboardTop) {
      // Keyboard opened/closed — re-measure after the frame settles.
      _baseBottom = null;
      _refloat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refloat();
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  /// Focus changed: rebuild for the grow/gray-ring style, then recompute
  /// whether the field also needs to float above the keyboard.
  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
    _refloat();
  }

  void _refloat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final focused = widget.focusNode.hasFocus;
      final keyboardTop = widget.keyboardTop;

      if (!focused || keyboardTop == null) {
        if (_target != 0) setState(() => _target = 0);
        return;
      }

      // Measure once, in the rest position, before the transform lifts.
      if (_baseBottom == null) {
        final box = context.findRenderObject();
        if (box is! RenderBox || !box.attached) return;
        final top = box.localToGlobal(Offset.zero).dy;
        _baseBottom = top + box.size.height;
      }

      final floatLine = keyboardTop - kFieldFloatGap;
      final target = _baseBottom! > floatLine
          ? -(_baseBottom! - floatLine)
          : 0.0;
      if (target != _target) {
        setState(() => _target = target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Size + ring apply ONLY while the field floats above the keyboard.
    final floating = _target != 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Floating style: grow to span everything but 5px on each side of
        // the screen (paint-only scale — no re-layout), plus a tiny gray
        // ring. When the keyboard hides, everything tweens back to the
        // normal pill.
        const edgeGap = 5.0;
        final screenW = MediaQuery.sizeOf(context).width;
        final slotW = constraints.maxWidth;
        final widthScale = slotW > 0 ? (screenW - edgeGap * 2) / slotW : 1.0;

        return TweenAnimationBuilder<double>(
          tween: Tween(end: _target),
          duration: kFieldFloatDuration,
          curve: Curves.easeOutCubic,
          builder: (context, dy, floatedChild) {
            return Transform.translate(
              offset: Offset(0, dy),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: floating ? widthScale : 1.0),
                duration: kFieldFloatDuration,
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: kFieldFloatDuration,
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: floating
                            ? Border.all(color: const Color(0xFF9E9E9E))
                            : null,
                      ),
                      child: child,
                    ),
                  );
                },
                child: floatedChild,
              ),
            );
          },
          child: widget.child,
        );
      },
    );
  }
}

// ---------------------------- pickers ----------------------------

/// Same dark barrier as the country picker.
const _kPickerBarrier = Color(0x8C1D1507);

Future<void> _pickGender(BuildContext context, AuthController c) async {
  final gender = await showDialog<String>(
    context: context,
    barrierColor: _kPickerBarrier,
    builder: (_) => GenderPickerDialog(selected: c.gender),
  );
  if (gender != null) c.setGender(gender);
}

Future<void> _pickAge(BuildContext context, AuthController c) async {
  final age = await showDialog<int>(
    context: context,
    barrierColor: _kPickerBarrier,
    builder: (_) =>
        AgePickerDialog(selected: int.tryParse(c.ageController.text)),
  );
  if (age != null) c.setAge(age);
}

// ---------------------------- field ----------------------------

/// Height of the pill fields, same baseline as the phone bar / buttons.
const double _kControlHeight = 56;

/// White pill text field, black text — the phone-screen bar look.
class _RegisterField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;

  const _RegisterField({
    required this.controller,
    required this.hint,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kControlHeight,
      padding: const EdgeInsets.only(left: 20, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: _PillTextField(
        controller: controller,
        hint: hint,
        focusNode: focusNode,
      ),
    );
  }
}

/// A bare TextField wearing the shared auth "no default decoration" theme
/// (kills the app-level focus bar), black cursor + selection.
class _PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _PillTextField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.black.withValues(alpha: 0.2),
          selectionHandleColor: Colors.black,
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Focus(
          focusNode: focusNode,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            cursorColor: Colors.black,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------- picker pill ----------------------------

/// White pill opening a picker card: shows the chosen value (or the hint)
/// plus a chevron — visually identical to the other register rows.
class _PickerPill extends StatelessWidget {
  final String? label;
  final String hint;
  final VoidCallback onTap;

  const _PickerPill({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kControlHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: label == null
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: AuthGlyph(
                  AuthGlyphType.chevronDown,
                  color: Color(0x941D1507),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------- button ----------------------------

/// Ink pill button — twin of the phone screen's "Send code" pill, with the
/// bubble loader while submitting.
class _RegisterButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _RegisterButton({
    required this.label,
    required this.loading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (onPressed != null || loading) ? 1 : 0.5,
      child: SizedBox(
        height: _kControlHeight,
        child: Material(
          color: AuthColors.ink,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            splashColor: AuthColors.gold.withValues(alpha: 0.18),
            highlightColor: AuthColors.gold.withValues(alpha: 0.08),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: loading
                    ? AuthDots(
                        key: const ValueKey('loading'),
                        color: AuthColors.paper,
                      )
                    : Text(
                        label,
                        key: ValueKey(label),
                        style: const TextStyle(
                          fontSize: 16.5,
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
    );
  }
}
