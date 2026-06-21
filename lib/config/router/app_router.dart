import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';
import '../../core/session/app_session.dart';
import '../../features/app_shell/app_shell_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/product/presentation/screens/product_detail_screen.dart';
import '../../features/product/presentation/screens/product_not_found_screen.dart';
import '../../features/product/presentation/screens/edit_product_screen.dart';
import '../../features/product/presentation/screens/ingredients_camera_screen.dart';
import '../../features/product/presentation/screens/ingredients_verification_screen.dart';
import '../../features/product/presentation/screens/manual_ingredients_screen.dart';
import '../../features/scanner/presentation/screens/food_result_screen.dart';
import '../../features/meals/presentation/screens/meals_screen.dart';
import '../../features/meals/presentation/screens/meal_detail_screen.dart';
import '../../features/meals/domain/entities/meal_entry_entity.dart';
import '../../features/premium/presentation/screens/paywall_screen.dart';
import '../../features/profile/presentation/screens/allergen_selection_screen.dart';
import '../../features/profile/presentation/screens/diet_filter_screen.dart';
import '../../features/profile/presentation/screens/oil_filter_screen.dart';
import '../../features/profile/presentation/screens/chemical_filter_screen.dart';
import '../../features/product/presentation/screens/additive_detail_screen.dart';
import '../../features/comparison/presentation/screens/comparison_screen.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Land on Meals: scanner is heavy (camera init + permission), so a
    // cold-launch on its tab can stutter on low-end Androids. Meals is a
    // local Drift read — instant. The user reaches the scanner via the
    // (still-centered, still-prominent) middle nav button when ready.
    initialLocation: '/meals',
    debugLogDiagnostics: kDebugMode,
    onException: (context, state, router) {
      debugPrint('[GoRouter] No route for: ${state.uri}');
      router.go('/meals');
    },
    redirect: (context, state) {
      final path = state.uri.path;

      // Root path has no route — send to meals (initial landing).
      if (path == '/' || path.isEmpty) return '/meals';

      // The /reset-password route is allowed regardless of auth state:
      // the deep-link from the password reset email puts Supabase into
      // a `passwordRecovery` session, so the user IS technically signed
      // in, but redirecting them straight to /meals would skip the
      // whole point of the email link. Treat it as a special-case
      // public route.
      final isResetRoute = state.matchedLocation == '/reset-password';
      if (isResetRoute) return null;

      // Supabase başlatılmamışsa login'e yönlendir
      if (!SupabaseConfig.isInitialized) {
        final isAuthRoute =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password';
        if (!isAuthRoute) return '/login';
        return null;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      // Guest mode: user explicitly chose "continue without account".
      // They get the same route access as logged-in users; the only
      // gated screens (premium purchase, community submit) check
      // `isGuestProvider` themselves and show a register prompt.
      final isGuest = ref.read(isGuestProvider);
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isGuest && !isAuthRoute) {
        return '/login';
      }
      // Only fully-authenticated users get bounced off the auth
      // routes. Guests must be allowed to walk into /register so
      // they can upgrade their session — the previous version of
      // this branch trapped guests on /meals when they tapped the
      // "Hesap aç" CTA.
      if (isLoggedIn && isAuthRoute) {
        return '/meals';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: RouteNames.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/scanner',
            name: RouteNames.scanner,
            builder: (context, state) => const ScannerScreen(),
          ),
          GoRoute(
            path: '/history',
            name: RouteNames.history,
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/meals',
            name: RouteNames.meals,
            builder: (context, state) => const MealsScreen(),
          ),
          GoRoute(
            path: '/favorites',
            name: RouteNames.favorites,
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'allergens',
                name: RouteNames.allergenSelection,
                builder: (context, state) => const AllergenSelectionScreen(),
              ),
              GoRoute(
                path: 'diets',
                name: RouteNames.dietFilter,
                builder: (context, state) => const DietFilterScreen(),
              ),
              GoRoute(
                path: 'oils',
                name: RouteNames.oilFilter,
                builder: (context, state) => const OilFilterScreen(),
              ),
              GoRoute(
                path: 'chemicals',
                name: RouteNames.chemicalFilter,
                builder: (context, state) => const ChemicalFilterScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/product/:barcode',
        name: RouteNames.productDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return ProductDetailScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: '/product/:barcode/edit',
        name: RouteNames.editProduct,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          final extra = state.extra as Map<String, dynamic>?;
          return EditProductScreen(barcode: barcode, productInfo: extra);
        },
      ),
      GoRoute(
        path: '/product/:barcode/not-found',
        name: RouteNames.productNotFound,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return ProductNotFoundScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: '/additive/:eCode',
        name: RouteNames.additiveDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final eCode = state.pathParameters['eCode']!;
          return AdditiveDetailScreen(eCode: eCode);
        },
      ),
      GoRoute(
        path: '/product/:barcode/ocr',
        name: RouteNames.ingredientsCamera,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          final extra = state.extra as Map<String, dynamic>?;
          return IngredientsCameraScreen(barcode: barcode, productInfo: extra);
        },
      ),
      GoRoute(
        path: '/product/:barcode/verify',
        name: RouteNames.ingredientsVerification,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          final extra = state.extra as Map<String, dynamic>?;
          return IngredientsVerificationScreen(barcode: barcode, extra: extra);
        },
      ),
      GoRoute(
        path: '/product/:barcode/manual',
        name: RouteNames.manualIngredients,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ManualIngredientsScreen(barcode: barcode, productInfo: extra);
        },
      ),
      GoRoute(
        path: '/food-result',
        name: RouteNames.foodResult,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final imageBytes = state.extra;
          if (imageBytes is! Uint8List) {
            // Fallback: redirect to scanner if extra is missing or wrong type
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.goNamed(RouteNames.scanner);
            });
            return const SizedBox.shrink();
          }
          return FoodResultScreen(imageBytes: imageBytes);
        },
      ),
      GoRoute(
        path: '/meal-detail',
        name: RouteNames.mealDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final meal = state.extra;
          if (meal is! MealEntryEntity) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.goNamed(RouteNames.meals);
            });
            return const SizedBox.shrink();
          }
          return MealDetailScreen(meal: meal);
        },
      ),
      GoRoute(
        path: '/paywall',
        name: RouteNames.paywall,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/compare',
        name: RouteNames.compare,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final a = extra?['a'] as String?;
          final b = extra?['b'] as String?;
          if (a == null || b == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.goNamed(RouteNames.meals);
            });
            return const SizedBox.shrink();
          }
          return ComparisonScreen(barcodeA: a, barcodeB: b);
        },
      ),
    ],
  );
}
