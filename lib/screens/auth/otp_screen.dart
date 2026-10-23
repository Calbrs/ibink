import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_screen.dart';

/// Same height as the "Send code" button and the phone field.
const double _kControlHeight = 56;

/// Step 2 — code confirmation. Auto-submits when the 6th digit is typed.
class OtpScreen extends StatelessWidget {
  final AuthController controller;
  const OtpScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final waiting = c.resendSeconds > 0;
    final checking = c.isLoading && c.otpController.text.length == 6;
    final resending = c.isLoading && !checking;
    final isRegister = c.otpMode == OtpMode.register;
    final dial = c.selectedCountry.dialCode;

    // Social handoffs arrive with a token only — the seller's own email /
    // phone never reached the app, so show a neutral target on the card.
    final email = c.emailController.text.trim();
    final knowsPhone = c.phoneController.text.trim().isNotEmpty;
    final phone = knowsPhone
        ? authPrettyPhone(c.fullPhone, dial)
        : 'your phone number';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Header ----------
        AuthHeading(
          title: isRegister ? 'Verify Your Email' : 'Verify Your Phone',
        ),
        const SizedBox(height: 24),

        // ---------- Code target card ----------
        isRegister
            ? _EmailCard(
                email: email.isEmpty ? 'your email' : email,
                onChange: c.isLoading ? null : c.backToRegister,
              )
            : _PhoneCard(
                isoCode: c.selectedCountry.isoCode,
                dialCode: dial,
                phone: phone,
                onChange: c.isLoading ? null : c.changePhoneNumber,
              ),
        const SizedBox(height: 28),

        AuthErrorBanner(c.errorMsg),

        // ---------- OTP boxes ----------
        OtpBoxes(controller: c.otpController, errorTick: c.errorTick),

        // ---------- Status ----------
        SizedBox(
          height: 44,
          child: Center(
            child: checking
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BubbleLoader(color: AuthColors.inkSoft, dotSize: 6),
                      SizedBox(width: 10),
                      Text(
                        'Checking code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AuthColors.inkSoft,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),

        // ---------- Resend ----------
        _ResendButton(
          label: waiting
              ? 'Resend code in 0:${c.resendSeconds.toString().padLeft(2, '0')}'
              : 'Resend code',
          loading: resending,
          onPressed: (waiting || c.isLoading) ? null : c.resendOtp,
        ),
      ],
    );
  }
}

// ---------------------------- bubble loader ----------------------------

/// Three horizontal bubbles that bounce, scale and fade in a wave.
class _BubbleLoader extends StatefulWidget {
  final Color color;
  final double dotSize;

  const _BubbleLoader({super.key, required this.color, this.dotSize = 9});

  @override
  State<_BubbleLoader> createState() => _BubbleLoaderState();
}

class _BubbleLoaderState extends State<_BubbleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.dotSize;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset in phase so the motion travels left → right.
            final phase = (_ctrl.value - i * 0.18) % 1.0;
            final v = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.39),
              child: Transform.translate(
                offset: Offset(0, -size * 0.45 * v),
                child: Transform.scale(
                  scale: 0.65 + 0.35 * v,
                  child: Opacity(
                    opacity: 0.4 + 0.6 * v,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------- phone card ----------------------------

/// White "ticket" (same background as the phone input field): small label +
/// Change pill on top, flag and the big number below. A cropped sun-disc with
/// ripples sits in the top-right corner.
class _PhoneCard extends StatelessWidget {
  final String isoCode;
  final String dialCode;
  final String phone;
  final VoidCallback? onChange;
  const _PhoneCard({
    required this.isoCode,
    required this.dialCode,
    required this.phone,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChange != null;
    final hasDial = phone.startsWith(dialCode);
    final dialPart = hasDial ? dialCode : '';
    final restPart = hasDial ? phone.substring(dialCode.length) : phone;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _CardMotifPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- label + change pill ----
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CODE SENT TO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onChange,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.black.withValues(
                                alpha: enabled ? 0.8 : 0.3,
                              ),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withValues(
                                alpha: enabled ? 1 : 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ---- flag + big number ----
                  Row(
                    children: [
                      CountryFlag.fromCountryCode(
                        isoCode,
                        theme: const ImageTheme(
                          width: 34,
                          height: 24,
                          shape: RoundedRectangle(5),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (dialPart.isNotEmpty)
                                  TextSpan(
                                    text: dialPart,
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                TextSpan(text: restPart),
                              ],
                            ),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Register-mode variant of [_PhoneCard]: same white ticket, same motif,
/// but it shows the email the code was sent to instead of a phone number.
class _EmailCard extends StatelessWidget {
  final String email;
  final VoidCallback? onChange;
  const _EmailCard({required this.email, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final enabled = onChange != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _CardMotifPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- label + change pill ----
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CODE SENT TO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onChange,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.black.withValues(
                                alpha: enabled ? 0.8 : 0.3,
                              ),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withValues(
                                alpha: enabled ? 1 : 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ---- email ----
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      email,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet ripples + sun-disc cropped at the card's top-right corner.
class _CardMotifPainter extends CustomPainter {
  const _CardMotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.96, size.height * 0.05);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      ring.color = Colors.black.withValues(alpha: 0.08 - i * 0.014);
      canvas.drawCircle(center, 44 + i * 26.0, ring);
    }

    canvas.drawCircle(
      center,
      26,
      Paint()..color = Colors.black.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant _CardMotifPainter old) => false;
}

// ---------------------------- resend button ----------------------------

/// Same look as the "Send code" button (ink background, light paper label).
/// Dimmed while disabled (countdown).
class _ResendButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _ResendButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: (enabled || loading) ? 1 : 0.5,
      child: SizedBox(
        height: _kControlHeight,
        child: Material(
          color: AuthColors.ink,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: AuthColors.gold.withValues(alpha: 0.18),
            highlightColor: AuthColors.gold.withValues(alpha: 0.08),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: loading
                    ? const _BubbleLoader(
                        key: ValueKey('loading'),
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

// ---------------------------- OTP boxes ----------------------------

/// Six white cells (same look as the phone field) driven by one invisible
/// text field, black digits. Shakes (with a haptic tap) whenever [errorTick]
/// changes.
class OtpBoxes extends StatefulWidget {
  final TextEditingController controller;
  final int errorTick;
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.errorTick,
  });

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> with TickerProviderStateMixin {
  static const _length = 6;
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
    _blink.repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant OtpBoxes old) {
    super.didUpdateWidget(old);
    if (old.errorTick != widget.errorTick) {
      _shake.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.removeListener(_rebuild);
    _focus.dispose();
    _shake.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final active = _focus.hasFocus && text.length < _length ? text.length : -1;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < _length; i++)
                    Expanded(
                      child: _Cell(
                        char: i < text.length ? text[i] : null,
                        active: i == active,
                        blink: _blink,
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: _length,
                    maxLines: null,
                    expands: true,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String? char;
  final bool active;
  final Animation<double> blink;
  const _Cell({required this.char, required this.active, required this.blink});

  @override
  Widget build(BuildContext context) {
    final filled = char != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: filled
            ? Text(
                char!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              )
            : active
            ? FadeTransition(
                opacity: blink,
                child: Container(
                  width: 2,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
