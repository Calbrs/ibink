import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/session.dart';
import '../routes/app_routes.dart';

import '../widgets/app_shimmer.dart';

enum _AuthStep { phone, otp, shopName }

// FIX: Backend validation (UserProfileController::completeProfile) requires
// 'business_type' => 'required|string|in:Individual,Company'
// The previous list (Electronics, Fashion & Clothing, ...) does not match
// this validation rule at all, which is why the API always rejected it with
// "business type is not supported by the database".
const _businessTypeOptions = <String>[
  'Individual',
  'Company',
];

const _regionOptions = <String>[
  'Dar es Salaam',
  'Arusha',
  'Dodoma',
  'Mwanza',
  'Mbeya',
  'Morogoro',
  'Tanga',
  'Kilimanjaro',
  'Iringa',
  'Tabora',
  'Kigoma',
  'Shinyanga',
  'Singida',
  'Rukwa',
  'Ruvuma',
  'Mtwara',
  'Lindi',
  'Pwani',
  'Manyara',
  'Kagera',
  'Mara',
  'Simiyu',
  'Geita',
  'Njombe',
  'Katavi',
  'Songwe',
  'Zanzibar Mjini Magharibi',
  'Kaskazini Unguja',
  'Kusini Unguja',
  'Kaskazini Pemba',
  'Kusini Pemba',
];

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthStep _step = _AuthStep.phone;
  bool _isLoading = false;
  int _otpAttempts = 0;
  String? _errorMsg;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _shopNameController = TextEditingController();

  String? _businessType;
  String? _locationRegion;


  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    final stripped = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+255$stripped';
  }

  String _slugify(String name) {
    var slug = name.trim().toLowerCase();
    slug = slug.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    return slug;
  }

  bool _isSlugTakenError(ApiResponse res) {
    return res.fieldErrorContains('store_slug', 'taken');
  }

  // FIX: helper to detect "already registered" response coming back from
  // completeProfile (Kiswahili message: "Namba hii tayari imesajiliwa...")
  // or from verifyWhatsAppOtp, so the UI can react correctly instead of
  // just showing a generic error and getting stuck.
  bool _isAlreadyRegisteredError(ApiResponse res) {
    final msg = res.error?.toLowerCase() ?? '';
    return msg.contains('tayari imesajiliwa') || msg.contains('already registered');
  }

  bool _isInvalidBusinessTypeError(ApiResponse res) {
    return res.fieldErrorContains('business_type', 'invalid') ||
        res.fieldErrorContains('business_type', 'selected') ||
        res.fieldErrorContains('business_type', 'must be');
  }

  // ------------------------------------------------------------
  // 1. SEND OTP
  // ------------------------------------------------------------
  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _errorMsg = 'Please enter your phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final res = await ApiClient.instance.post(
        ApiConfig.sendWhatsAppOtpEndpoint,
        {'phone_number': _fullPhone},
      );

      if (!mounted) return;

      if (!res.success) {
        setState(() {
          _isLoading = false;
          _errorMsg = res.error ?? 'Failed to send OTP. Please try again.';
        });
        _showSnack(_errorMsg!);
        return;
      }

      setState(() {
        _isLoading = false;
        _step = _AuthStep.otp;
        _otpAttempts = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = 'Network error: $e';
      });
      _showSnack(_errorMsg!);
    }
  }

  // ------------------------------------------------------------
  // 2. VERIFY OTP
  // ------------------------------------------------------------
  Future<void> _verifyOtp() async {
    final rawOtp = _otpController.text.trim();
    if (rawOtp.isEmpty) {
      setState(() => _errorMsg = 'Please enter the OTP code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      if (kDebugMode) {
        debugPrint('[OTP] Verifying OTP with WhatsAppController...');
      }

      final otpRes = await ApiClient.instance.post(
        ApiConfig.verifyWhatsAppOtpEndpoint,
        {'phone_number': _fullPhone, 'otp': rawOtp},
      );

      if (!mounted) return;

      if (!otpRes.success) {
        setState(() {
          _isLoading = false;
          _otpAttempts += 1;
          _errorMsg = otpRes.error ?? 'Invalid code. Please try again.';
        });
        _showSnack(_errorMsg!);
        if (_otpAttempts >= 3) {
          _showSnack('You have reached the maximum attempts. Please resend OTP.');
        }
        return;
      }

      // --- OTP verified successfully ---
      final data = otpRes.data!;
      final isRegistered = data['is_registered'] == true;
      final token = data['access_token'] as String?;

      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Authentication failed. No token received.';
        });
        _showSnack(_errorMsg!);
        return;
      }

      // Set the token (Sanctum or registration‑proof)
      ApiClient.instance.setToken(token);

      if (isRegistered) {
        // Existing user: save session and go to dashboard
        await Session.instance.saveLogin(data);
        if (kDebugMode) debugPrint('[OTP] Existing user, navigating to dashboard');
        setState(() => _isLoading = false);
        if (mounted) {
          context.go(AppRoutes.dashboard);
        }
      } else {
        // New user: store the registration‑proof token and ask for shop details

        setState(() {
          _isLoading = false;
          _step = _AuthStep.shopName;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[OTP] Exception: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpAttempts += 1;
        _errorMsg = 'Network error: $e';
      });
      _showSnack(_errorMsg!);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final res = await ApiClient.instance.post(
        ApiConfig.sendWhatsAppOtpEndpoint,
        {'phone_number': _fullPhone},
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _otpAttempts = 0;
        _otpController.clear();
      });

      _showSnack(res.success ? 'New code has been sent.' : (res.error ?? 'Failed to send code. Please try again.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Network error: $e');
    }
  }

  Future<void> _changePhoneNumber() async {
    setState(() {
      _step = _AuthStep.phone;
      _otpController.clear();
      _otpAttempts = 0;
      _errorMsg = null;

      _businessType = null;
      _locationRegion = null;
    });
  }

  // ------------------------------------------------------------
  // 3. COMPLETE PROFILE (New user)
  // ------------------------------------------------------------
  Future<void> _submitShopName() async {
    final shopName = _shopNameController.text.trim();
    if (shopName.isEmpty) {
      setState(() => _errorMsg = 'Please enter your shop name.');
      return;
    }

    final baseSlug = _slugify(shopName);
    if (baseSlug.isEmpty) {
      setState(() => _errorMsg = 'Please include some letters or numbers in your shop name.');
      return;
    }

    // FIX: business_type must be exactly 'Individual' or 'Company' to satisfy
    // backend validation: 'business_type' => 'required|string|in:Individual,Company'
    if (_businessType == null || _businessType!.isEmpty) {
      setState(() => _errorMsg = 'Please select your business type (Individual or Company).');
      return;
    }

    if (_locationRegion == null || _locationRegion!.isEmpty) {
      setState(() => _errorMsg = 'Please select your region.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Ensure we have the registration‑proof token
    ApiClient.instance.ensureTokenIsSet();
    if (!ApiClient.instance.hasToken) {
      if (kDebugMode) debugPrint('[Profile] No registration‑proof token available!');
      setState(() {
        _isLoading = false;
        _errorMsg = 'Session expired. Please login again.';
      });
      _showSnack(_errorMsg!);
      _goBackToPhone();
      return;
    }

    const maxAttempts = 5;
    var candidateSlug = baseSlug;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (kDebugMode) {
          debugPrint('[Profile] Attempt $attempt: completing profile with shop "$shopName" ($candidateSlug) ...');
        }

        final res = await ApiClient.instance.post(
          ApiConfig.completeProfileEndpoint,
          {
            'role': 'seller',
            'store_name': shopName,
            'store_slug': candidateSlug,
            'whatsapp_number': _fullPhone,
            // FIX: now sends exactly 'Individual' or 'Company' as required
            // by the backend Validator rule, instead of a store category
            // string like 'Electronics' which always failed validation.
            'business_type': _businessType,
            'location_region': _locationRegion,
          },
        );

        if (!mounted) return;

        if (res.success) {
          // Profile created – replace token with Sanctum token
          final data = res.data!;
          final newToken = data['access_token'] as String?;
          if (newToken == null || newToken.isEmpty) {
            setState(() {
              _isLoading = false;
              _errorMsg = 'Failed to obtain access token. Please try again.';
            });
            _showSnack(_errorMsg!);
            return;
          }

          ApiClient.instance.setToken(newToken);
          await Session.instance.saveLogin(data);

          if (kDebugMode) {
            debugPrint('[Profile] Profile completed successfully!');
            debugPrint('[Profile] User ID: ${Session.instance.userId}');
            debugPrint('[Profile] Role: ${Session.instance.role}');
          }

          setState(() => _isLoading = false);
          if (mounted) {
            context.go(AppRoutes.dashboard);
          }
          return;
        }

        // Handle specific errors
        if (res.statusCode == 401) {
          if (kDebugMode) debugPrint('[Profile] Unauthenticated! Token invalid.');
          setState(() {
            _isLoading = false;
            _errorMsg = 'Session expired. Please login again.';
          });
          _showSnack(_errorMsg!);
          _goBackToPhone();
          return;
        }

        // FIX: backend returns 400 with "Namba hii tayari imesajiliwa..."
        // when the phone was registered between OTP verification and this
        // request (race condition/replay guard in completeProfile()).
        // Previously this fell through to a generic error and the user got
        // stuck retrying with the same (now-invalid) registration token.
        if (res.statusCode == 400 && _isAlreadyRegisteredError(res)) {
          setState(() {
            _isLoading = false;
            _errorMsg = 'This number is already registered. Please login instead.';
          });
          _showSnack(_errorMsg!);
          _goBackToPhone();
          return;
        }

        // FIX: explicit handling for invalid business_type validation errors
        // so the message shown to the user is clear and actionable.
        if (_isInvalidBusinessTypeError(res)) {
          setState(() {
            _isLoading = false;
            _errorMsg = 'Please select a valid business type (Individual or Company).';
          });
          _showSnack(_errorMsg!);
          return;
        }

        if (_isSlugTakenError(res) && attempt < maxAttempts) {
          candidateSlug = '$baseSlug-${attempt + 1}';
          if (kDebugMode) {
            debugPrint('[Profile] Slug taken, retrying with "$candidateSlug" ...');
          }
          continue;
        }

        setState(() {
          _isLoading = false;
          _errorMsg = res.error ?? 'Failed to save shop details. Please try again.';
        });
        _showSnack(_errorMsg!);
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMsg = 'Network error: $e';
        });
        _showSnack(_errorMsg!);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMsg = 'That shop name is very popular! Please try a slightly different name.';
    });
    _showSnack(_errorMsg!);
  }

  void _goBackToPhone() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _step = _AuthStep.phone;
          _otpController.clear();
          _otpAttempts = 0;
          _errorMsg = null;

          _businessType = null;
          _locationRegion = null;
        });
      }
    });
  }

  // ------------------------------------------------------------
  // Social login (placeholders)
  // ------------------------------------------------------------
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _showSnack('Google sign in working (placeholder)');
      await Session.instance.setLoggedIn(true);
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Google error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _showSnack('Apple sign in working (placeholder)');
      await Session.instance.setLoggedIn(true);
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Apple error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ------------------------------------------------------------
  // Build methods
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return currentChild ?? const SizedBox.shrink();
                    },
                    child: _buildStepWidget(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepWidget() {
    switch (_step) {
      case _AuthStep.phone:
        return _buildPhoneStep();
      case _AuthStep.otp:
        return _buildOtpStep();
      case _AuthStep.shopName:
        return _buildShopNameStep();
    }
  }

  Widget _buildLogo() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        children: [
          TextSpan(text: 'iBink', style: TextStyle(color: AppColors.ink)),
          TextSpan(text: '.me', style: TextStyle(color: AppColors.green)),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    if (_errorMsg == null) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _errorMsg!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey<String>('phone_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _buildLogo(),
        const SizedBox(height: 40),
        const Text(
          'Welcome Back',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your WhatsApp number to continue',
          style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 32),
        _errorBanner(),
        _PhoneField(controller: _phoneController),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: AppShimmerSpinner(),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/google.png', width: 24, height: 24),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Google',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _signInWithApple,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/apple.png', width: 24, height: 24),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Apple',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey<String>('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _buildLogo(),
        const SizedBox(height: 40),
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a code to '),
              TextSpan(
                text: _fullPhone,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _errorBanner(),
        _OtpField(controller: _otpController),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: AppShimmerSpinner(),
                  )
                : const Text(
                    'Verify & Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _resendOtp,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Center(
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _changePhoneNumber,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Center(
                    child: Text(
                      'Change phone number',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShopNameStep() {
    return Column(
      key: const ValueKey<String>('shop_name_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _buildLogo(),
        const SizedBox(height: 40),
        const Text(
          'Name Your Shop',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        const Text(
          'Almost done. This is how buyers will find you on iBink.',
          style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 32),
        _errorBanner(),
        const _FieldLabel('Shop Name'),
        const SizedBox(height: 8),
        _ShopNameField(controller: _shopNameController),
        const SizedBox(height: 20),
        // FIX: dropdown now shows Individual / Company, matching backend
        // validation exactly ('required|string|in:Individual,Company').
        const _FieldLabel('Business Type'),
        const SizedBox(height: 8),
        _SearchableSelectField(
          label: 'Business Type',
          hintText: 'Select Individual or Company',
          options: _businessTypeOptions,
          value: _businessType,
          onChanged: (value) => setState(() => _businessType = value),
        ),
        const SizedBox(height: 20),
        const _FieldLabel('Region'),
        const SizedBox(height: 8),
        _SearchableSelectField(
          label: 'Region',
          hintText: 'Select your region',
          options: _regionOptions,
          value: _locationRegion,
          onChanged: (value) => setState(() => _locationRegion = value),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitShopName,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: AppShimmerSpinner(),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// UI Widgets (unchanged)
// ---------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
    );
  }
}

class _PhoneField extends StatefulWidget {
  final TextEditingController controller;
  const _PhoneField({required this.controller});

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Enter Your WhatsApp Number',
        labelStyle: TextStyle(
          color: _focusNode.hasFocus ? AppColors.green : AppColors.inkSoft,
          fontSize: 15,
        ),
        hintText: '712 345 678',
        hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 15.5),
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppColors.green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        prefixText: '+255 ',
        prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
    );
  }
}

class _OtpField extends StatefulWidget {
  final TextEditingController controller;
  const _OtpField({required this.controller});

  @override
  State<_OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<_OtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _focusNode.hasFocus ? AppColors.green.withValues(alpha: 0.6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 12),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _ShopNameField extends StatefulWidget {
  final TextEditingController controller;
  const _ShopNameField({required this.controller});

  @override
  State<_ShopNameField> createState() => _ShopNameFieldState();
}

class _ShopNameFieldState extends State<_ShopNameField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'e.g. Calbrs Electronics',
        hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 15.5),
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppColors.green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

class _SearchableSelectField extends StatefulWidget {
  final String label;
  final String hintText;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  const _SearchableSelectField({
    required this.label,
    required this.hintText,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SearchableSelectField> createState() => _SearchableSelectFieldState();
}

class _SearchableSelectFieldState extends State<_SearchableSelectField> {
  Future<void> _openPicker() async {
    final result = await showModalBottomSheet<String>(useRootNavigator: true, context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectPickerSheet(
        title: widget.label,
        options: widget.options,
        currentValue: widget.value,
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      widget.onChanged(result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null && widget.value!.isNotEmpty;

    return GestureDetector(
      onTap: _openPicker,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? widget.value! : widget.hintText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue ? AppColors.ink : AppColors.inkFaint,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.inkSoft, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SelectPickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? currentValue;

  const _SelectPickerSheet({
    required this.title,
    required this.options,
    required this.currentValue,
  });

  @override
  State<_SelectPickerSheet> createState() => _SelectPickerSheetState();
}

class _SelectPickerSheetState extends State<_SelectPickerSheet> {
  final _searchController = TextEditingController();
  final _otherController = TextEditingController();
  bool _showOtherInput = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.trim().isEmpty) return widget.options;
    final q = _query.trim().toLowerCase();
    return widget.options.where((o) => o.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: !_showOtherInput
                        ? Column(
                            key: const ValueKey<String>('list_mode'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) => setState(() => _query = v),
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Tafuta...',
                                    hintStyle: const TextStyle(
                                      color: AppColors.inkFaint,
                                      fontSize: 15,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: AppColors.inkSoft,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.panel,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                  itemCount: _filtered.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == _filtered.length) {
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.green,
                                        ),
                                        title: const Text(
                                          'Nyingine (Andika Mwenyewe)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.green,
                                          ),
                                        ),
                                        onTap: () => setState(() => _showOtherInput = true),
                                      );
                                    }
                                    final option = _filtered[index];
                                    final isSelected = option == widget.currentValue;
                                    return ListTile(
                                      title: Text(
                                        option,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_rounded, color: AppColors.green)
                                          : null,
                                      onTap: () => Navigator.pop(context, option),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            key: const ValueKey<String>('other_mode'),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _otherController,
                                  autofocus: true,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: 'Andika hapa...',
                                    hintStyle: const TextStyle(
                                      color: AppColors.inkFaint,
                                      fontSize: 15.5,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.panel,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => setState(() => _showOtherInput = false),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppColors.line),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Text(
                                          'Rudi',
                                          style: TextStyle(
                                            color: AppColors.ink,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          final text = _otherController.text.trim();
                                          if (text.isEmpty) return;
                                          Navigator.pop(context, text);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Text(
                                          'Tumia Hii',
                                          style: TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}