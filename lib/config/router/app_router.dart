import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';
import '../../features/app_shell/app_shell_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/product/presentation/screens/product_detail_screen.dart';
import '../../features/product/presentation/screens/product_not_found_screen.dart';
import '../../features/product/presentation/screens/ingredients_camera_screen.dart';
import '../../features/product/presentation/screens/ingredients_verification_screen.dart';
import '../../features/product/presentation/screens/manual_ingredients_screen.dart';
import '../../features/profile/presentation/screens/allergen_selection_screen.dart';
import '../../features/profile/presentation/screens/diet_filter_screen.dart';
import '../../features/profile/presentation/screens/oil_filter_screen.dart';
import '../../features/profile/presentation/screens/chemical_filter_screen.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/scanner',
    redirect: (context, state) {
      // Supabase başlatılmamışsa login'e yönlendir
      if (!SupabaseConfig.isInitialized) {
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        if (!isAuthRoute) return '/login';
        return null;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/scanner';
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
                builder: (context, state) =>
                    const AllergenSelectionScreen(),
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
                builder: (context, state) =>
                    const ChemicalFilterScreen(),
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
        path: '/product/:barcode/not-found',
        name: RouteNames.productNotFound,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return ProductNotFoundScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: '/product/:barcode/ocr',
        name: RouteNames.ingredientsCamera,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return IngredientsCameraScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: '/product/:barcode/verify',
        name: RouteNames.ingredientsVerification,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          final extra = state.extra as Map<String, dynamic>?;
          return IngredientsVerificationScreen(
            barcode: barcode,
            extra: extra,
          );
        },
      ),
      GoRoute(
        path: '/product/:barcode/manual',
        name: RouteNames.manualIngredients,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return ManualIngredientsScreen(barcode: barcode);
        },
      ),
    ],
  );
}
