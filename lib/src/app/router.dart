import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/add_tracks/presentation/add_tracks_screen.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/news/presentation/news_list_screen.dart';
import '../features/photos/presentation/photos_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/rules/presentation/rule_detail_screen.dart';
import '../features/rules/presentation/rules_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/support/presentation/support_chat_screen.dart';
import '../features/tracks/presentation/tracks_screen.dart';
import 'widgets/app_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.isLoggedIn;
      final isSplashRoute = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      // Still loading auth state - show splash
      if (isLoading) {
        return isSplashRoute ? null : '/splash';
      }

      // Done loading, redirect from splash to appropriate screen
      if (isSplashRoute) {
        return isLoggedIn ? '/' : '/login';
      }

      // Not logged in and not on auth route - redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Logged in but on auth route - redirect to home
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/photos',
                builder: (context, state) => const PhotosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracks',
                builder: (context, state) => const TracksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) => const InvoicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add-tracks',
                builder: (context, state) => const AddTracksScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const AppScaffold(
          title: 'Поиск',
          showSearch: false,
          child: SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const AppScaffold(
          title: 'Поддержка',
          child: SupportChatScreen(),
        ),
      ),
      GoRoute(
        path: '/news',
        builder: (context, state) => const AppScaffold(
          title: 'Новости',
          child: NewsListScreen(),
        ),
        routes: [
          GoRoute(
            path: ':slug',
            builder: (context, state) {
              final slug = state.pathParameters['slug'] ?? '';
              return AppScaffold(
                title: 'Статья',
                child: NewsDetailScreen(slug: slug),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const AppScaffold(
          title: 'Профиль',
          child: ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/rules',
        builder: (context, state) => const AppScaffold(
          title: 'Правила',
          child: RulesScreen(),
        ),
        routes: [
          GoRoute(
            path: ':slug',
            builder: (context, state) {
              final slug = state.pathParameters['slug'] ?? '';
              return AppScaffold(
                title: 'Правило',
                child: RuleDetailScreen(slug: slug),
              );
            },
          ),
        ],
      ),
    ],
  );
});

/// Notifier that triggers router refresh when auth state changes
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
