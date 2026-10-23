import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../models/product_model.dart';
import '../models/payment_confirmation.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/products/product_form_screen.dart';
import '../models/order_model.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/products/product_detail_screen.dart';
import '../screens/dashboard/revenue_screen.dart';
import '../screens/dashboard/notifications_screen.dart';
import '../screens/tools/barcodes_screen.dart';
import '../screens/tiktok/tiktok_callback_screen.dart';
import '../screens/tiktok/tiktok_screen.dart';
import '../screens/tiktok/tiktok_webview_screen.dart';
import '../screens/tiktok/tiktok_videos_screen.dart';
import '../screens/tiktok/tiktok_settings_screen.dart';
import '../screens/tiktok/tiktok_video_player_screen.dart';
import '../screens/tools/logs_screen.dart';
import '../screens/payments/payment_inbox_screen.dart';
import '../screens/payments/payment_review_screen.dart';
import 'app_browser.dart';

class AppRoutes {
  AppRoutes._();
  static const String splash = '/';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String settings = '/profile/settings';
  static const String productForm = '/products/form';
  static const String revenue = '/dashboard/revenue';
  static const String notifications = '/dashboard/notifications';
  static const String browser = '/browser';
  static const String barcodes = '/profile/barcodes';
  static const String tiktokCallback = '/tiktok/callback';
  static const String tiktokWebView = '/tiktok/webview';
  static const String tiktokVideos = '/tiktok/videos';
  static const String tiktokSettings = '/tiktok/settings';
  static const String tiktokVideoPlayer = '/tiktok/video';
  static const String tiktok = '/tiktok';
  static const String payments = '/payments';
  static const String paymentReview = '/payments/review';
  static const String logs = '/profile/logs';
}

/// Helper Method ya kutengeneza Bounce Transition (inayoiga motion ya navbar yako)
CustomTransitionPage<T> _buildBouncyPageTransition<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 1. Scale Transition: Inaanza ndogo (0.88) na kutanuka na bounce (Curves.easeOutBack)
      final scaleTransition = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack, // Inapaa na kudunda kwa mbele
          reverseCurve: Curves.easeInBack, // Inajikunja kwa nyuma unaporudi
        ),
      );

      // 2. Fade Transition: Inafanya screen ionekane (Appear) na kupotea (Gone) kwa ulaini
      final fadeTransition = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

      return FadeTransition(
        opacity: fadeTransition,
        child: ScaleTransition(scale: scaleTransition, child: child),
      );
    },
    // Muda wa transition kulingana na kasi ya app yako
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (context, state) =>
          _buildBouncyPageTransition(state: state, child: const SplashScreen()),
      redirect: (context, state) => null,
    ),
    GoRoute(
      path: AppRoutes.auth,
      pageBuilder: (context, state) =>
          _buildBouncyPageTransition(state: state, child: const AuthScreen()),
      redirect: (context, state) {
        if (Session.instance.isLoggedIn) {
          return AppRoutes.dashboard;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (context, state) => _buildBouncyPageTransition(
        state: state,
        child: const SettingsScreen(),
      ),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.productForm,
      pageBuilder: (context, state) {
        final extra = state.extra;
        return _buildBouncyPageTransition(
          state: state,
          child: ProductFormScreen(
            product: extra is ProductModel ? extra : null,
          ),
        );
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: '${AppRoutes.products}/:id',
      pageBuilder: (context, state) {
        final extra = state.extra;
        final childWidget = extra is ProductModel
            ? ProductDetailScreen(product: extra)
            : const ProductsScreen();

        return _buildBouncyPageTransition(state: state, child: childWidget);
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.revenue,
      pageBuilder: (context, state) => _buildBouncyPageTransition(
        state: state,
        child: const RevenueScreen(),
      ),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.notifications,
      pageBuilder: (context, state) => _buildBouncyPageTransition(
        state: state,
        child: const NotificationsScreen(),
      ),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.browser,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final data = extra is Map<String, String>
            ? extra
            : const <String, String>{};
        return _buildBouncyPageTransition(
          state: state,
          child: AppBrowserScreen(
            url: data['url'] ?? '',
            title: data['title'] ?? '',
          ),
        );
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.barcodes,
      pageBuilder: (context, state) => _buildBouncyPageTransition(
        state: state,
        child: const BarcodesScreen(),
      ),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.logs,
      pageBuilder: (context, state) =>
          _buildBouncyPageTransition(state: state, child: const LogsScreen()),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.tiktokSettings,
      pageBuilder: (context, state) => _buildBouncyPageTransition(
        state: state,
        child: const TikTokSettingsScreen(),
      ),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.tiktokVideos,
      pageBuilder: (context, state) => _buildBouncyPageTransition(
        state: state,
        child: const TikTokVideosScreen(),
      ),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.tiktokVideoPlayer,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final data = extra is Map ? extra : const <String, dynamic>{};
        return _buildBouncyPageTransition(
          state: state,
          child: TikTokVideoPlayerScreen(
            videoId: (data['id'] as String?) ?? '',
            title: (data['title'] as String?) ?? 'Video',
            embedLink: data['embed'] as String?,
          ),
        );
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.tiktokWebView,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final url = extra is Map ? extra['url'] as String? : null;
        if (url == null || url.isEmpty) {
          return _buildBouncyPageTransition(
            state: state,
            child: const TikTokScreen(),
          );
        }
        return _buildBouncyPageTransition(
          state: state,
          child: TikTokWebViewScreen(url: url),
        );
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.tiktokCallback,
      pageBuilder: (context, state) {
        // Prefer `extra` from the WebView hand-off; fall back to query params
        // so a future deep link (ibink://tiktok/callback?code=…&state=…)
        // keeps working without changing this route.
        final extra = state.extra;
        final code = extra is Map && extra['code'] is String
            ? extra['code'] as String
            : (state.uri.queryParameters['code'] ?? '');
        final stateParam = extra is Map && extra['state'] is String
            ? extra['state'] as String
            : (state.uri.queryParameters['state'] ?? '');
        return _buildBouncyPageTransition(
          state: state,
          child: TikTokCallbackScreen(code: code, state: stateParam),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.tiktok,
      pageBuilder: (context, state) =>
          _buildBouncyPageTransition(state: state, child: const TikTokScreen()),
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.payments,
      pageBuilder: (context, state) {
        final statusStr = state.uri.queryParameters['status'];
        PaymentConfirmationStatus? filter;
        if (statusStr != null) {
          try {
            filter = PaymentConfirmationStatus.values.firstWhere(
              (e) => e.name == statusStr,
            );
          } catch (_) {}
        }
        return _buildBouncyPageTransition(
          state: state,
          child: PaymentInboxScreen(initialFilter: filter),
        );
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),
    GoRoute(
      path: AppRoutes.paymentReview,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final confirmation = extra is PaymentConfirmation ? extra : null;
        return _buildBouncyPageTransition(
          state: state,
          child: confirmation != null
              ? PaymentReviewScreen(confirmation: confirmation)
              : const PaymentInboxScreen(),
        );
      },
      redirect: (context, state) {
        if (!Session.instance.isLoggedIn) {
          return AppRoutes.auth;
        }
        return null;
      },
    ),

    // StatefulShellRoute inabaki vile vile kwani kurasa zake (Tabs) zinatunzwa
    // kwenye kumbukumbu (IndexedStack) kwa ajili ya kubadili haraka bila kupoteza state.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (c, s) => const DashboardScreen(),
              redirect: (c, s) {
                if (!Session.instance.isLoggedIn) return AppRoutes.auth;
                return null;
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.products,
              builder: (c, s) => const ProductsScreen(),
              redirect: (c, s) {
                if (!Session.instance.isLoggedIn) return AppRoutes.auth;
                return null;
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.orders,
              builder: (c, s) {
                final statusStr = s.uri.queryParameters['status'];
                OrderStatus? filter;
                if (statusStr != null) {
                  try {
                    filter = OrderStatus.values.firstWhere(
                      (e) => e.name == statusStr,
                    );
                  } catch (_) {}
                }
                return OrdersScreen(initialFilter: filter);
              },
              redirect: (c, s) {
                if (!Session.instance.isLoggedIn) return AppRoutes.auth;
                return null;
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (c, s) => const ProfileScreen(),
              redirect: (c, s) {
                if (!Session.instance.isLoggedIn) return AppRoutes.auth;
                return null;
              },
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ukurasa haujapatikana',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.go(
                Session.instance.isLoggedIn
                    ? AppRoutes.dashboard
                    : AppRoutes.auth,
              );
            },
            child: const Text('Rudi Nyumbani'),
          ),
        ],
      ),
    ),
  ),
);

class _NavItem {
  final String iconAsset;
  final String activeIconAsset;
  final String label;
  const _NavItem({
    required this.iconAsset,
    required this.activeIconAsset,
    required this.label,
  });
}

const _navItems = [
  _NavItem(
    iconAsset: 'assets/icons/dashboard_outline.png',
    activeIconAsset: 'assets/icons/dashboard_filled.png',
    label: 'Home',
  ),
  _NavItem(
    iconAsset: 'assets/icons/products_outline.png',
    activeIconAsset: 'assets/icons/products_filled.png',
    label: 'Bidhaa',
  ),
  _NavItem(
    iconAsset: 'assets/icons/orders_outline.png',
    activeIconAsset: 'assets/icons/orders_filled.png',
    label: 'Oda',
  ),
  _NavItem(
    iconAsset: 'assets/icons/profile_outline.png',
    activeIconAsset: 'assets/icons/profile_filled.png',
    label: 'Wasifu',
  ),
];

class _AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _AppShell({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: shell,
      bottomNavigationBar: _PilledNavBar(
        currentIndex: shell.currentIndex,
        onSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}

class _PilledNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _PilledNavBar({required this.currentIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 5,
      ),
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1507),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isActive = index == currentIndex;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.elasticOut,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  transform: Matrix4.translationValues(0, isActive ? -6 : 0, 0),
                  transformAlignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: isActive ? 1.22 : 1.0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        child: isActive
                            ? ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.gold,
                                        AppColors.goldLight,
                                      ],
                                    ).createShader(bounds),
                                child: Image.asset(
                                  item.activeIconAsset,
                                  width: 22,
                                  height: 22,
                                  color: Colors.white,
                                ),
                              )
                            : Image.asset(
                                item.iconAsset,
                                width: 22,
                                height: 22,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        child: AnimatedOpacity(
                          opacity: isActive ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: isActive
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                )
                              : const SizedBox(width: 0, height: 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
