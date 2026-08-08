import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../routes/app_routes.dart';
import '../widgets/app_shimmer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    // Logo "inainuka" kidogo kwa spring (rise) kisha inatulia (fall/settle) -
    // sawa na animation ya nav bar tuliyoongeza kwenye app shell.
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    _animController.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // Muda huu wa kusubiri ndio unaofanya splash ionekane vizuri kwa
    // mtumiaji kabla ya kuhamia auth/dashboard. Router upande wa
    // app_router.dart sasa HAIRUKI splash - inaruhusu ukurasa huu
    // kuchorwa kikamilifu kwanza.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;

    if (mounted) {
      context.go(loggedIn ? AppRoutes.dashboard : AppRoutes.auth);
    }
  }

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
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                          children: [
                            TextSpan(text: 'iBink', style: TextStyle(color: AppColors.ink)),
                            TextSpan(text: '.me', style: TextStyle(color: AppColors.green)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SELLER',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Simamia biashara yako, popote ulipo',
                        style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 40),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: AppShimmerSpinner(),
                      ),
                    ],
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