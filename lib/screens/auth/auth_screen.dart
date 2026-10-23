import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:world_code_picker/country_code_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/country_list.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/app_logger.dart';
import '../../core/session.dart';
import '../../routes/app_routes.dart';
import '_country_picker_dialog.dart';
import 'oauth_webview_screen.dart';
import 'otp_screen.dart';
import 'phone_screen.dart';
import 'register_screen.dart';

/// Auth shell: owns the shared [AuthController] and shows the current step
/// on the gold Onbaio canvas. Brand sits on top, the active step sits at the
/// bottom within thumb reach.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final AuthController _c;

  static const _transparentStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_transparentStyle);
    _c = AuthController(
      onNotice: _notice,
      onAuthenticated: () {
        if (mounted) context.go(AppRoutes.dashboard);
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _notice(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: AuthColors.paper,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AuthColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _pickCountry() async {
    final country = await showDialog<Country>(
      context: context,
      barrierColor: const Color(0x8C1D1507),
      builder: (ctx) {
        return CountryPickerDialog(
          countries: defaultCountries,
          selected: _c.selectedCountry,
        );
      },
    );
    if (country != null && mounted) {
      _c.setCountry(country);
    }
  }

  Widget _currentStep() {
    switch (_c.step) {
      case AuthStep.phone:
        return PhoneScreen(
          key: const ValueKey(AuthStep.phone),
          controller: _c,
          onPickCountry: _pickCountry,
        );
      case AuthStep.register:
        return RegisterScreen(
          key: const ValueKey(AuthStep.register),
          controller: _c,
          onPickCountry: _pickCountry,
        );
      case AuthStep.otp:
        return OtpScreen(key: const ValueKey(AuthStep.otp), controller: _c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AuthColors.ink,
          selectionColor: AuthColors.ink.withValues(alpha: 0.22),
          selectionHandleColor: AuthColors.ink,
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AuthColors.gold,
        body: AuthBackdrop(
          child: SafeArea(
            top: false,
            child: ListenableBuilder(
              listenable: _c,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final padTop = MediaQuery.of(context).padding.top + 10.0;
                    final padBottom = 20.0;
                    final available =
                        (constraints.maxHeight - padTop - padBottom).clamp(
                          0.0,
                          double.infinity,
                        );
                    final reduceMotion = MediaQuery.disableAnimationsOf(
                      context,
                    );
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(24, padTop, 24, padBottom),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: available,
                          maxHeight: available,
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 2000),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Expanded → the step screens get BOUNDED
                              // height (no AnimatedSwitcher Stack unbounded
                              // constraints), so their inner layouts can
                              // safely use Expanded/Spacer.
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeIn,
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.topCenter,
                                    children: [...previous, ?current],
                                  ),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.04),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _currentStep(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Auth flow: constants + AuthController (all logic).

// ---------------------------- constants ----------------------------
enum AuthStep { phone, register, otp }

/// Which pending verification the OTP screen works on: the phone-login
/// two-factor challenge (`/auth/two-factor/challenge`) or the email
/// registration code (`/auth/register/verify`).
enum OtpMode { login, register }

// ---------------------------- controller ----------------------------

/// All auth state + API logic. The screens only read from this and
/// call its methods, so each screen file stays purely visual.
///
/// Flow (onbaio.com/api):
///  - Login:  POST /auth/login → two_factor_token → send-code →
///    /auth/two-factor/challenge (code from the OTP boxes).
///  - Register: the phone screen collects the email, the register screen
///    collects the names/phone, POST /auth/register returns a draft token,
///    and POST /auth/register/verify confirms the 6-digit email code.
class AuthController extends ChangeNotifier {
  AuthController({required this.onNotice, required this.onAuthenticated}) {
    phoneController.addListener(notifyListeners);
    otpController.addListener(_onOtpChanged);
  }

  static const _tag = 'Auth';
  static const resendCooldown = 30;

  final void Function(String message) onNotice;
  final VoidCallback onAuthenticated;

  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  // Register form (step: register). The email is prefilled from the
  // phone screen; the backend also requires first/last name.
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final registerPhoneController = TextEditingController();
  final ageController = TextEditingController();

  /// Chosen from the gender pill (Male / Female / Other).
  String? gender;

  Country selectedCountry = const Country(
    name: 'Tanzania',
    isoCode: 'TZ',
    dialCode: '+255',
  );

  void setCountry(Country country) {
    selectedCountry = country;
    notifyListeners();
  }

  AuthStep step = AuthStep.phone;

  /// Login (two-factor challenge) or register (email code) — decides
  /// which endpoint the OTP screen verifies against and which resend
  /// endpoint it uses.
  OtpMode otpMode = OtpMode.login;

  bool isLoading = false;
  int otpAttempts = 0;
  int errorTick = 0; // bumps on every error, used to shake the OTP boxes
  int resendSeconds = 0;
  String? errorMsg;

  /// Login: the two-factor challenge token. Register: the registration
  /// draft token identifying the pending seller until the code is verified.
  String? _challengeToken;

  /// 'google' | 'apple' when the active register-OTP flow came through a
  /// social handoff (its verify/resend endpoints differ); null = the plain
  /// email form.
  String? _socialProvider;

  Timer? _timer;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    phoneController.dispose();
    otpController.dispose();
    emailController.dispose();
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    registerPhoneController.dispose();
    ageController.dispose();
    super.dispose();
  }

  // ---------------------------- helpers ----------------------------

  String get fullPhone {
    final raw = phoneController.text.trim();
    final stripped = raw.startsWith('0') ? raw.substring(1) : raw;
    return '${selectedCountry.dialCode}$stripped';
  }

  /// Phone number from the register form, normalised the same way as a
  /// login number, e.g. "0712 345 678" → "+255712345678".
  String get registerFullPhone {
    final raw = registerPhoneController.text.trim();
    final digits = raw.replaceAll(' ', '');
    final stripped = digits.startsWith('0') ? digits.substring(1) : digits;
    return '${selectedCountry.dialCode}$stripped';
  }

  void _fail(String msg) {
    isLoading = false;
    errorMsg = msg;
    errorTick++;
    notifyListeners();
  }

  /// Verify / resend endpoint for the active register flow — the social
  /// drafts verify through their provider's endpoints, the email form's
  /// through /auth/register/*.
  String get _registerVerifyEndpoint {
    switch (_socialProvider) {
      case 'google':
        return ApiConfig.googleVerifyEndpoint;
      case 'apple':
        return ApiConfig.appleVerifyEndpoint;
      default:
        return ApiConfig.registerVerifyEndpoint;
    }
  }

  String get _registerResendEndpoint {
    switch (_socialProvider) {
      case 'google':
        return ApiConfig.googleResendEndpoint;
      case 'apple':
        return ApiConfig.appleResendEndpoint;
      default:
        return ApiConfig.registerResendEndpoint;
    }
  }

  void _startCountdown({int seconds = resendCooldown}) {
    _timer?.cancel();
    resendSeconds = seconds > 0 ? seconds : resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendSeconds <= 1) {
        resendSeconds = 0;
        t.cancel();
      } else {
        resendSeconds--;
      }
      notifyListeners();
    });
  }

  void _onOtpChanged() {
    notifyListeners();
    // Auto-submit as soon as the 6th digit lands.
    if (otpController.text.length == 6 && !isLoading && step == AuthStep.otp) {
      verifyOtp();
    }
  }

  // ------------------------------------------------------------
  // 1. LOGIN (phone number)
  // ------------------------------------------------------------
  Future<void> login() async {
    if (phoneController.text.trim().isEmpty) {
      errorMsg = 'Enter your phone number to continue.';
      errorTick++;
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMsg = null;
    _socialProvider = null; // phone login is never a social flow
    notifyListeners();

    try {
      final res = await ApiClient.instance.post(ApiConfig.loginEndpoint, {
        'phone_number': fullPhone,
      });
      if (_disposed) return;

      if (!res.success) {
        if (res.statusCode == 404) {
          // Backend: {action: "register"} — the account does not exist.
          _fail(res.error ?? 'Account not found. Please register first.');
          return;
        }
        _fail(res.error ?? 'Could not log in. Try again.');
        return;
      }

      final token = res.data?['two_factor_token'] as String?;
      if (token == null || token.isEmpty) {
        _fail('Sign-in failed: no two-factor challenge received.');
        return;
      }

      _challengeToken = token;
      otpMode = OtpMode.login;
      step = AuthStep.otp;
      otpAttempts = 0;
      otpController.clear();
      _startCountdown();

      // The code itself is delivered by the two-factor send-code endpoint
      // (login does not send it — the authenticator page requests it).
      _sendTwoFactorCode();

      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _fail('Network error: $e');
    }
  }

  /// Fire-and-forget: asks the backend to deliver the two-factor code.
  /// The two-factor response contract is not finalised, so failures are
  /// only logged — the user can still hit "Resend code" manually.
  Future<void> _sendTwoFactorCode() async {
    final token = _challengeToken;
    if (token == null) return;
    final res = await ApiClient.instance.post(
      ApiConfig.twoFactorSendCodeEndpoint,
      {'token': token},
    );
    if (_disposed) return;
    if (!res.success) {
      AppLogger.instance.warn(
        _tag,
        'two-factor send-code failed: ${res.error}',
      );
    }
  }

  // ------------------------------------------------------------
  // 2. REGISTER (email form)
  // ------------------------------------------------------------
  /// Called from the phone screen when the user hits "Register" with an
  /// email typed in. Moves to the register form with the email prefilled.
  void startRegister({required String email}) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      errorMsg = 'Enter your email first.';
      errorTick++;
      notifyListeners();
      return;
    }
    errorMsg = null;
    emailController.text = trimmed;
    step = AuthStep.register;
    notifyListeners();
  }

  void backToRegister() {
    _timer?.cancel();
    resendSeconds = 0;
    otpController.clear();
    otpAttempts = 0;
    errorMsg = null;
    step = AuthStep.register;
    notifyListeners();
  }

  /// Chosen from the gender pill (Male / Female / Other).
  void setGender(String v) {
    gender = v;
    notifyListeners();
  }

  /// Wheel-picker result — stored on the same controller the submit uses.
  void setAge(int v) {
    ageController.text = '$v';
    notifyListeners();
  }

  Future<void> register() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final middleName = middleNameController.text.trim();
    final email = emailController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      errorMsg = 'First name and last name are required.';
      errorTick++;
      return notifyListeners();
    }
    if (!email.contains('@')) {
      errorMsg = 'Enter a valid email address.';
      errorTick++;
      return notifyListeners();
    }

    final ageRaw = ageController.text.trim();
    final age = int.tryParse(ageRaw);
    if (ageRaw.isNotEmpty && (age == null || age < 1 || age > 120)) {
      errorMsg = 'Enter a valid age (1–120).';
      errorTick++;
      return notifyListeners();
    }

    isLoading = true;
    errorMsg = null;
    _socialProvider = null; // the email form's own flow
    notifyListeners();

    try {
      final res = await ApiClient.instance.post(ApiConfig.registerEndpoint, {
        'first_name': firstName,
        if (middleName.isNotEmpty) 'middle_name': middleName,
        'last_name': lastName,
        'gender': ?gender,
        'age': ?age,
        'phone_number': registerFullPhone,
        'email': email,
      });
      if (_disposed) return;

      if (!res.success) {
        // Backend failure codes: email_taken/exists (422), locked/cooldown/
        // send_limit (429), server errors — the message comes pre-worded.
        _fail(res.error ?? 'Registration failed. Try again.');
        return;
      }

      final token = res.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        _fail('Registration failed: no verification token received.');
        return;
      }

      _challengeToken = token;
      otpMode = OtpMode.register;
      step = AuthStep.otp;
      otpAttempts = 0;
      otpController.clear();
      final retryAfter = res.data?['retry_after'];
      _startCountdown(
        seconds: retryAfter is int && retryAfter > 0
            ? retryAfter
            : resendCooldown,
      );
      notifyListeners();
      onNotice('Code sent to $email. Check your inbox.');
    } catch (e) {
      if (_disposed) return;
      _fail('Network error: $e');
    }
  }

  // ------------------------------------------------------------
  // 3. VERIFY OTP (two modes: login challenge / registration code)
  // ------------------------------------------------------------
  Future<void> verifyOtp() async {
    final rawOtp = otpController.text.trim();
    if (rawOtp.length < 6) {
      errorMsg = 'Enter the 6-digit code.';
      errorTick++;
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMsg = null;
    notifyListeners();

    try {
      if (otpMode == OtpMode.register) {
        await _verifyRegisterOtp(rawOtp);
      } else {
        await _verifyLoginOtp(rawOtp);
      }
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'OTP verification threw', e, st);
      if (_disposed) return;
      otpAttempts += 1;
      _fail('Network error: $e');
    }
  }

  /// POST /auth/two-factor/challenge. The response contract is not
  /// finalised — accept a bearer token when the backend returns one,
  /// otherwise continue on the session cookie the backend authenticated.
  Future<void> _verifyLoginOtp(String code) async {
    final token = _challengeToken;
    if (token == null) {
      _fail('Challenge expired. Please log in again.');
      otpController.clear();
      _resetToPhone();
      return;
    }

    final res = await ApiClient.instance.post(
      ApiConfig.twoFactorChallengeEndpoint,
      {'token': token, 'code': code},
    );
    if (_disposed) return;

    if (!res.success) {
      otpAttempts += 1;
      otpController.clear();
      _fail(res.error ?? 'Wrong code. Try again.');
      if (otpAttempts >= 3) {
        onNotice('Too many wrong attempts. Resend a new code.');
      }
      return;
    }

    await _saveAuthentication(res.data!);

    AppLogger.instance.info(_tag, 'Two-factor challenge passed.');
    isLoading = false;
    notifyListeners();
    onAuthenticated();
  }

  /// POST /auth/register/verify (or the provider's /auth/{google,apple}/verify
  /// for a social draft). Success logs the new seller in via the
  /// backend session (no bearer token) and returns `{redirect: "/app"}`.
  Future<void> _verifyRegisterOtp(String code) async {
    final token = _challengeToken;
    if (token == null) {
      _fail('Registration draft expired. Please register again.');
      otpController.clear();
      _resetToPhone();
      return;
    }

    final res = await ApiClient.instance.post(_registerVerifyEndpoint, {
      'token': token,
      'code': code,
    });
    if (_disposed) return;

    if (!res.success) {
      otpAttempts += 1;
      otpController.clear();
      _fail(res.error ?? 'Wrong code. Check your email and try again.');
      return;
    }

    await _saveAuthentication(res.data!);

    AppLogger.instance.info(_tag, 'Registration verified.');
    isLoading = false;
    notifyListeners();
    onAuthenticated();
  }

  /// Defensive session saving: store a bearer token when the backend
  /// returns one (`token` / `access_token`); when it only starts a
  /// session, persist whatever seller/account payload came along.
  Future<void> _saveAuthentication(Map<String, dynamic> data) async {
    final bearer = (data['token'] ?? data['access_token']) as String?;
    if (bearer != null && bearer.isNotEmpty) {
      await Session.instance.saveLogin({
        ...data,
        'access_token': bearer,
        'is_registered': true,
      });
      return;
    }

    final seller = (data['seller'] ?? data['user']) as Map<String, dynamic>?;
    await Session.instance.saveLogin({
      ...data,
      'account_data': ?seller,
      'is_registered': true,
    });
  }

  Future<void> resendOtp() async {
    if (resendSeconds > 0 || isLoading) return;
    isLoading = true;
    errorMsg = null;
    notifyListeners();

    try {
      final isRegister = otpMode == OtpMode.register;
      final res = await ApiClient.instance.post(
        isRegister
            ? _registerResendEndpoint
            : ApiConfig.twoFactorSendCodeEndpoint,
        {'token': _challengeToken ?? ''},
      );
      if (_disposed) return;
      isLoading = false;
      otpAttempts = 0;
      otpController.clear();
      if (res.success) _startCountdown();
      notifyListeners();
      onNotice(
        res.success
            ? 'New code sent${isRegister ? ' to your email' : ''}.'
            : (res.error ?? 'Could not send the code. Try again.'),
      );
    } catch (e) {
      if (_disposed) return;
      isLoading = false;
      notifyListeners();
      onNotice('Network error: $e');
    }
  }

  void changePhoneNumber() {
    _timer?.cancel();
    resendSeconds = 0;
    _resetToPhone();
  }

  void _resetToPhone() {
    step = AuthStep.phone;
    otpController.clear();
    otpAttempts = 0;
    errorMsg = null;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // 4. SOCIAL (Google/Apple — OAuth via the in-app WebView)
  // ------------------------------------------------------------
  /// Called by the phone screen with the token captured from the backend's
  /// frontend redirect.
  ///
  /// Login tab (`/authenticator` landing): the token is a two-factor
  /// challenge — same flow as the phone login, resumed at the OTP step.
  /// Register tab (`/verify-otp` landing): the token identifies the social
  /// registration draft; the code is already in the seller's email, so the
  /// OTP step starts immediately and verifies via the provider's endpoints.
  void completeSocial(OAuthResult result) {
    _challengeToken = result.token;
    otpAttempts = 0;
    otpController.clear();
    errorMsg = null;

    if (result.isLogin) {
      _socialProvider = null;
      otpMode = OtpMode.login;
      step = AuthStep.otp;
      _startCountdown();
      // The code itself is delivered by the two-factor send-code endpoint
      // (fire-and-forget; "Resend code" covers any delivery hiccup).
      _sendTwoFactorCode();
    } else {
      _socialProvider = result.provider;
      otpMode = OtpMode.register;
      step = AuthStep.otp;
      // The social flow already emailed the code before the redirect.
      _startCountdown();
    }
    notifyListeners();
  }
}

// Onbaio auth kit: palette, gold backdrop, hand-drawn glyphs and the small
// widgets shared by splash / phone / OTP / shop screens.
//
// Design idea: one flat gold canvas, one warm ink colour. Gold is the
// brand, ink is the action. No shadows, no gradients, no stock icons.

/// Palette. Gold is the canvas, ink is everything you can touch.
abstract final class AuthColors {
  static const gold = Color(0xFFE5A83E);
  static const goldLight = Color(0xFFF1C468);
  // Pastel washes (replacing the orange backdrop).
  static const washLavender = Color.fromRGBO(221, 214, 243, 0.85);
  static const washPeach = Color.fromRGBO(255, 218, 193, 0.85);
  static const ink = Color(0xFF1D1507);
  static const paper = Color(0xFFFFF6DD);
  static const coral = Color(0xFFFF9275);

  // Ink at different strengths (for text and hairlines on gold).
  static const inkSoft = Color(0xAD1D1507); // 68%
  static const inkFaint = Color(0x661D1507); // 40%
  static const line = Color(0x401D1507); // 25%
  static const outline = Color(0x8C1D1507); // 55%

  // Light field fill on gold.
  static const fill = Color(0x4DFFFFFF); // 30% white

  // Paper at different strengths (for text and hairlines on ink).
  static const paperSoft = Color(0xB3FFF6DD);
  static const paperHint = Color(0x80FFF6DD);
  static const paperLine = Color(0x26FFF6DD);
  static const paperFaint = Color(0x14FFF6DD);
}

// ---------------------------- backdrop ----------------------------

/// Flat gold canvas with one quiet motif: a sun-disc and ripples cropped
/// at the top-right corner. With [animate] the ripples open once.
class AuthBackdrop extends StatefulWidget {
  final Widget child;
  final bool animate;
  const AuthBackdrop({super.key, required this.child, this.animate = false});

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop> {
  @override
  Widget build(BuildContext context) {
    // Pastel wash backdrop: lavender at the top blending into peach, over a
    // white base (the washes are 85%-alpha so the base shows through softly).
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AuthColors.washLavender, AuthColors.washPeach],
        ),
      ),
      child: widget.child,
    );
  }
}

// (sun/ripple motif removed)
// ---------------------------- glyphs ----------------------------

enum AuthGlyphType { chevronDown, check, close, search }

/// Hand-drawn line glyphs. Rounded strokes, no icon font.
class AuthGlyph extends StatelessWidget {
  final AuthGlyphType type;
  final Color color;
  final double size;
  final double strokeWidth;
  const AuthGlyph(
    this.type, {
    super.key,
    this.color = AuthColors.ink,
    this.size = 20,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(type, color, strokeWidth)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final AuthGlyphType type;
  final Color color;
  final double stroke;
  const _GlyphPainter(this.type, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case AuthGlyphType.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, h * 0.38)
            ..lineTo(w * 0.5, h * 0.64)
            ..lineTo(w * 0.78, h * 0.38),
          p,
        );
      case AuthGlyphType.check:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.2, h * 0.52)
            ..lineTo(w * 0.42, h * 0.72)
            ..lineTo(w * 0.8, h * 0.3),
          p,
        );
      case AuthGlyphType.close:
        canvas.drawLine(
          Offset(w * 0.28, h * 0.28),
          Offset(w * 0.72, h * 0.72),
          p,
        );
        canvas.drawLine(
          Offset(w * 0.72, h * 0.28),
          Offset(w * 0.28, h * 0.72),
          p,
        );
      case AuthGlyphType.search:
        canvas.drawCircle(Offset(w * 0.44, h * 0.44), w * 0.26, p);
        canvas.drawLine(
          Offset(w * 0.64, h * 0.64),
          Offset(w * 0.82, h * 0.82),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.type != type || old.color != color || old.stroke != stroke;
}

// ---------------------------- helpers ----------------------------

/// "+255712345678" -> "+255 712 345 678"
String authPrettyPhone(String fullPhone, String dialCode) {
  if (!fullPhone.startsWith(dialCode)) return fullPhone;
  final rest = fullPhone.substring(dialCode.length);
  final groups = <String>[];
  for (var i = 0; i < rest.length; i += 3) {
    groups.add(rest.substring(i, math.min(i + 3, rest.length)));
  }
  return groups.isEmpty ? dialCode : '$dialCode ${groups.join(' ')}';
}

// ---------------------------- brand ----------------------------

class AuthBrandRow extends StatelessWidget {
  final double logoHeight;
  const AuthBrandRow({super.key, this.logoHeight = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icons/onbaio web logo.png',
          height: logoHeight,
          fit: BoxFit.contain,
          semanticLabel: 'Onbaio',
        ),
      ],
    );
  }
}

// ---------------------------- text ----------------------------

class AuthHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? extra;

  /// Overridable scale/weight — the register screen uses a bigger,
  /// extra-bold title than the other steps.
  final double titleSize;
  final FontWeight titleWeight;
  final double subtitleSize;
  const AuthHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.extra,
    this.titleSize = 36,
    this.titleWeight = FontWeight.w800,
    this.subtitleSize = 15.5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: titleWeight,
            letterSpacing: -1.4,
            height: 1.02,
            color: AuthColors.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: subtitleSize,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AuthColors.inkSoft,
            ),
          ),
        ],
        if (extra != null) ...[const SizedBox(height: 10), extra!],
      ],
    );
  }
}

class AuthLabel extends StatelessWidget {
  final String text;
  const AuthLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AuthColors.inkSoft,
        ),
      ),
    );
  }
}

/// Underlined text action (Change, Resend code...).
class AuthTextLink extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const AuthTextLink(this.text, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: enabled ? AuthColors.ink : AuthColors.inkFaint,
            decoration: TextDecoration.underline,
            decorationThickness: 1.6,
          ),
        ),
      ),
    );
  }
}

// ---------------------------- feedback ----------------------------

/// Ink banner with a coral dot. Slides open when a message arrives.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AuthColors.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AuthColors.coral,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AuthColors.paper,
                          height: 1.35,
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

/// Three pulsing dots, used instead of a spinner.
class AuthDots extends StatefulWidget {
  final Color color;
  final double size;
  const AuthDots({super.key, this.color = AuthColors.ink, this.size = 8});

  @override
  State<AuthDots> createState() => _AuthDotsState();
}

class _AuthDotsState extends State<AuthDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              () {
                final t = (_c.value - i * 0.18 + 1) % 1.0;
                final v = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
                  child: Opacity(
                    opacity: 0.4 + 0.6 * v,
                    child: Transform.scale(
                      scale: 0.65 + 0.35 * v,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

// ---------------------------- buttons ----------------------------

/// Solid ink button, gold label.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final Color labelColor;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.labelColor = AuthColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: AuthColors.ink,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          splashColor: AuthColors.gold.withValues(alpha: 0.18),
          highlightColor: AuthColors.gold.withValues(alpha: 0.08),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: loading
                  ? const AuthDots(
                      key: ValueKey('loading'),
                      color: AuthColors.gold,
                    )
                  : Text(
                      label,
                      key: const ValueKey('label'),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                        color: labelColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transparent button with an ink outline.
class AuthOutlineButton extends StatelessWidget {
  final String label;
  final Widget? leading;
  final VoidCallback? onPressed;
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: SizedBox(
        height: 54,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AuthColors.outline, width: 1.4),
          ),
          child: InkWell(
            onTap: onPressed,
            splashColor: AuthColors.ink.withValues(alpha: 0.08),
            highlightColor: AuthColors.ink.withValues(alpha: 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------- fields ----------------------------

/// Light field shell on gold. Ink ring when focused.
class AuthFieldShell extends StatelessWidget {
  final bool focused;
  final Widget child;
  const AuthFieldShell({super.key, required this.focused, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: AuthColors.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? AuthColors.ink : AuthColors.line,
          width: focused ? 1.8 : 1.2,
        ),
      ),
      child: child,
    );
  }
}

/// Text field for the dark panels (country picker, region picker).
/// Text field for the dark panels (country picker, region picker).
/// Gold text on ink, single border, no focus bar.
class AuthDarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool search;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  const AuthDarkField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.autofocus = false,
    this.search = false,
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999), // pill
        border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
      ),
      child: Row(
        children: [
          if (search) ...[
            const AuthGlyph(
              AuthGlyphType.search,
              color: Colors.black,
              size: 18,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            // Local theme wipes the app-level InputDecorationTheme
            // (the green focus bar) for this field only.
            child: Theme(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  onChanged: onChanged,
                  textCapitalization: capitalization,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  cursorColor: Colors.black,
                  style: const TextStyle(
                    fontSize: 16,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.4),
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
}
