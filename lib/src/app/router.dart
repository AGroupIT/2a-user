import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_provider.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/news/presentation/news_list_screen.dart';
import '../features/payment_chat/presentation/payment_chat_screen.dart';
import '../features/photos/presentation/photos_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/rules/presentation/rule_detail_screen.dart';
import '../features/rules/presentation/rules_screen.dart';
import '../features/search/presentation/track_search_no_code_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/sp_finance/presentation/sp_assemblies_screen.dart';
import '../features/sp_finance/presentation/sp_assembly_detail_screen.dart';
import '../features/sp_finance/presentation/sp_track_edit_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/referral/presentation/referral_screen.dart';
import '../features/tariffs/presentation/tariffs_screen.dart';
import '../features/purchase_blanks/presentation/purchase_blank_detail_screen.dart';
import '../features/purchase_blanks/presentation/purchase_blanks_screen.dart';
import '../features/support/presentation/support_chat_screen.dart';
import '../features/tracks/presentation/tracks_screen.dart';
import 'widgets/app_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // НЕ используем ref.watch здесь — иначе GoRouter пересоздаётся при каждом
  // изменении authState (включая фоновое обновление clientData), что сбрасывает
  // navigation stack в initialLocation '/'. Вместо этого читаем authState прямо
  // внутри redirect через ref.read — он вызывается refreshListenable'ом.
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.isLoggedIn;
      final isSplashRoute = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      // Still loading auth state - show splash.
      // Исключение: если пользователь уже на экране входа/регистрации — остаёмся там.
      // Иначе нажатие "Войти" перебрасывает на сплэш на время API-запроса.
      if (isLoading) {
        if (isAuthRoute) return null;
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
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/calculator',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Калькулятор доставки',
          child: CalculatorScreen(),
        ),
      ),
      GoRoute(
        path: '/search-nocode',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Поиск по трек-номеру',
          child: TrackSearchNoCodeScreen(),
        ),
      ),
      GoRoute(
        path: '/support',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final initialMessage = state.extra as String?;
          return AppScaffold(
            title: 'Поддержка',
            child: SupportChatScreen(initialMessage: initialMessage),
          );
        },
      ),
      GoRoute(
        path: '/payment-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          String? initialMessage;
          String? invoiceId;
          String? invoiceNumber;
          double? amount;
          double? totalCostCny;
          double? totalCostRub;
          double? clientRubRate;
          double? clientYuanRate;

          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra as Map<String, dynamic>;
            initialMessage = extra['message'] as String?;
            invoiceId = extra['invoiceId'] as String?;
            invoiceNumber = extra['invoiceNumber'] as String?;
            amount = extra['amount'] as double?;
            totalCostCny = extra['totalCostCny'] as double?;
            totalCostRub = extra['totalCostRub'] as double?;
            clientRubRate = extra['clientRubRate'] as double?;
            clientYuanRate = extra['clientYuanRate'] as double?;
          } else if (state.extra is String) {
            initialMessage = state.extra as String?;
          }

          return AppScaffold(
            title: 'Чат по оплате',
            child: PaymentChatScreen(
              initialMessage: initialMessage,
              invoiceId: invoiceId,
              invoiceNumber: invoiceNumber,
              amount: amount,
              totalCostCny: totalCostCny,
              totalCostRub: totalCostRub,
              clientRubRate: clientRubRate,
              clientYuanRate: clientYuanRate,
            ),
          );
        },
      ),
      GoRoute(
        path: '/news',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Новости',
          child: NewsListScreen(),
        ),
        routes: [
          GoRoute(
            path: ':slug',
            parentNavigatorKey: _rootNavigatorKey,
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
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Профиль',
          child: ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/rules',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Правила',
          child: RulesScreen(),
        ),
        routes: [
          GoRoute(
            path: ':slug',
            parentNavigatorKey: _rootNavigatorKey,
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
      GoRoute(
        path: '/referral',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Реферальная программа',
          child: ReferralScreen(),
        ),
      ),
      GoRoute(
        path: '/tariffs',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Тарифы',
          child: TariffsScreen(),
        ),
      ),
      // SP Finance routes
      GoRoute(
        path: '/sp-finance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Совместные покупки',
          child: SpAssembliesScreen(),
        ),
        routes: [
          GoRoute(
            path: 'assemblies/:id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return AppScaffold(
                title: 'Детали сборки',
                child: SpAssemblyDetailScreen(assemblyId: id),
              );
            },
          ),
          GoRoute(
            path: 'tracks/:id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final extra = state.extra as Map<String, dynamic>?;
              final assemblyId = extra?['assemblyId'] as int;
              return AppScaffold(
                title: 'Редактирование трека',
                child: SpTrackEditScreen(
                  trackId: id,
                  assemblyId: assemblyId,
                ),
              );
            },
          ),
        ],
      ),
      // Purchase Blanks routes
      GoRoute(
        path: '/purchase-blanks',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppScaffold(
          title: 'Выкуп по бланку',
          child: PurchaseBlanksScreen(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return AppScaffold(
                title: 'Бланк #$id',
                child: PurchaseBlankDetailScreen(blankId: id),
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
    _ref.listen(authProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
