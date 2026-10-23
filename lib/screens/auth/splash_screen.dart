import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes/app_routes.dart';

import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _transparentStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_transparentStyle);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Give the brand a brief moment before routing.
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _transparentStyle,
      child: Scaffold(
        backgroundColor: AuthColors.gold,
        body: AuthBackdrop(
          animate: true,
          child: SafeArea(
            top: false,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - v)),
                    child: child,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/onbaio web logo.png',
                      height: 88,
                      fit: BoxFit.contain,
                      semanticLabel: 'Onbaio',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Onbaio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        color: AuthColors.ink,
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
