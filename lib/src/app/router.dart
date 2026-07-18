import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/logging/client_log_service.dart';
import '../core/ui/app_layout.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/auth/data/partner_link_provider.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/partner_link_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
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
import '../features/sp_finance/presentation/sp_assembly_detail_screen.dart';
import '../features/sp_finance/presentation/sp_track_edit_screen.dart';
import '../features/sp_finance/presentation/sp_v2_purchase_detail_screen.dart';
import '../features/sp_finance/presentation/sp_v2_purchases_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/referral/presentation/referral_screen.dart';
import '../features/tariffs/presentation/tariffs_screen.dart';
import '../features/purchase_blanks/presentation/purchase_blank_detail_screen.dart';
import '../features/purchase_blanks/presentation/purchase_blanks_screen.dart';
import '../features/self_buyout/presentation/self_buyout_screen.dart';
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
    observers: [SentryNavigatorObserver(), ClientLogNavigatorObserver()],
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.isLoggedIn;
      final isSplashRoute = state.matchedLocation == '/splash';
      final isPartnerLinkRoute = state.matchedLocation.startsWith(
        '/partner-connect/',
      );
      final routePartnerToken = isPartnerLinkRoute
          ? state.pathParameters['token']
          : null;
      final partnerLinkState = ref.read(partnerLinkProvider);
      if (routePartnerToken != null &&
          partnerLinkState.shouldCaptureRouteToken(routePartnerToken)) {
        unawaited(
          Future<void>.microtask(
            () => ref
                .read(partnerLinkProvider.notifier)
                .captureToken(routePartnerToken),
          ),
        );
      }
      final pendingPartnerToken = partnerLinkState.pendingTokenForRoute(
        routePartnerToken,
      );
      final isAuthRoute =
          state.matchedLocation == '/login' ||
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
        if (!isLoggedIn) return '/login';
        return pendingPartnerToken != null
            ? '/partner-connect/$pendingPartnerToken'
            : '/';
      }

      // Not logged in and not on auth route - redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Logged in but on auth route - redirect to home
      if (isLoggedIn && isAuthRoute) {
        return pendingPartnerToken != null
            ? '/partner-connect/$pendingPartnerToken'
            : '/';
      }

      // Токен мог быть восстановлен после cold start уже на домашнем роуте.
      // Завершаем привязку до загрузки бизнес-экранов.
      if (isLoggedIn && pendingPartnerToken != null && !isPartnerLinkRoute) {
        return '/partner-connect/$pendingPartnerToken';
      }

      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        name: 'splash',
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        name: 'login',
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: 'register',
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        name: 'forgot-password',
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        name: 'partner-connect',
        path: '/partner-connect/:token',
        builder: (context, state) =>
            PartnerLinkScreen(token: state.pathParameters['token'] ?? ''),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [ClientLogNavigatorObserver()],
            routes: [
              GoRoute(
                name: 'home',
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [ClientLogNavigatorObserver()],
            routes: [
              GoRoute(
                name: 'photos',
                path: '/photos',
                builder: (context, state) => const PhotosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [ClientLogNavigatorObserver()],
            routes: [
              GoRoute(
                name: 'tracks',
                path: '/tracks',
                builder: (context, state) {
                  final query = state.uri.queryParameters;
                  return TracksScreen(
                    initialTrackId: int.tryParse(query['trackId'] ?? ''),
                    initialTrackCode: query['trackCode'],
                    initialAssemblyId: int.tryParse(query['assemblyId'] ?? ''),
                    initialClientCode: query['clientCode'],
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [ClientLogNavigatorObserver()],
            routes: [
              GoRoute(
                name: 'invoices',
                path: '/invoices',
                builder: (context, state) => InvoicesScreen(
                  initialInvoiceId: state.uri.queryParameters['invoiceId'],
                  initialClientCode: state.uri.queryParameters['clientCode'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [ClientLogNavigatorObserver()],
            routes: [
              GoRoute(
                name: 'support',
                path: '/support',
                builder: (context, state) {
                  final initialMessage = state.extra as String?;
                  return SupportChatScreen(initialMessage: initialMessage);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/more', redirect: (context, state) => '/'),
      GoRoute(
        name: 'calculator',
        path: '/calculator',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(
            title: 'Калькулятор доставки',
            child: CalculatorScreen(),
          ),
        ),
      ),
      GoRoute(
        name: 'search-nocode',
        path: '/search-nocode',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          AppScaffold(
            title: 'Поиск по трек-номеру',
            child: TrackSearchNoCodeScreen(
              initialQuery: state.uri.queryParameters['query'],
            ),
          ),
        ),
      ),
      GoRoute(
        name: 'payment-chat',
        path: '/payment-chat',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
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

          return _adaptivePage(
            context,
            state,
            AppScaffold(
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
            ),
          );
        },
      ),
      GoRoute(
        name: 'news',
        path: '/news',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(title: 'Новости', child: NewsListScreen()),
        ),
        routes: [
          GoRoute(
            name: 'news-detail',
            path: ':slug',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) {
              final slug = state.pathParameters['slug'] ?? '';
              return _adaptivePage(
                context,
                state,
                AppScaffold(
                  title: 'Статья',
                  child: NewsDetailScreen(slug: slug),
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        name: 'profile',
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(title: 'Профиль', child: ProfileScreen()),
        ),
      ),
      GoRoute(
        name: 'rules',
        path: '/rules',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(title: 'Правила', child: RulesScreen()),
        ),
        routes: [
          GoRoute(
            name: 'rule-detail',
            path: ':slug',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) {
              final slug = state.pathParameters['slug'] ?? '';
              return _adaptivePage(
                context,
                state,
                AppScaffold(
                  title: 'Правило',
                  child: RuleDetailScreen(slug: slug),
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        name: 'referral',
        path: '/referral',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(
            title: 'Реферальная программа',
            child: ReferralScreen(),
          ),
        ),
      ),
      GoRoute(
        name: 'tariffs',
        path: '/tariffs',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(title: 'Тарифы', child: TariffsScreen()),
        ),
      ),
      // SP Finance routes
      GoRoute(
        name: 'sp-finance',
        path: '/sp-finance',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(
            title: 'Совместные покупки',
            child: SpV2PurchasesScreen(),
          ),
        ),
        routes: [
          GoRoute(
            name: 'sp-v2-purchase-detail',
            path: 'purchases/:id',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return _adaptivePage(
                  context,
                  state,
                  const _InvalidLinkScreen(
                    reason: 'Некорректный ID совместной покупки',
                  ),
                );
              }
              return _adaptivePage(
                context,
                state,
                AppScaffold(
                  title: 'Совместная покупка',
                  child: SpV2PurchaseDetailScreen(purchaseId: id),
                ),
              );
            },
          ),
          GoRoute(
            name: 'sp-assembly-detail',
            path: 'assemblies/:id',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) {
              // PU-S6: int.tryParse с invalid screen вместо int.parse,
              // чтобы кривой URL (`/sp-finance/assemblies/abc`) не валил
              // приложение exception'ом, а показывал понятную ошибку.
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return _adaptivePage(
                  context,
                  state,
                  const _InvalidLinkScreen(reason: 'Некорректный ID сборки'),
                );
              }
              return _adaptivePage(
                context,
                state,
                AppScaffold(
                  title: 'Детали сборки',
                  child: SpAssemblyDetailScreen(assemblyId: id),
                ),
              );
            },
          ),
          GoRoute(
            name: 'sp-track-edit',
            path: 'tracks/:id',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) {
              // PU-S6: int.tryParse и для path id, и для query assemblyId.
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return _adaptivePage(
                  context,
                  state,
                  const _InvalidLinkScreen(reason: 'Некорректный ID трека'),
                );
              }
              // PU-H4: assemblyId можно передать как query (?assemblyId=42),
              // если переход внутри приложения — через state.extra (legacy).
              // Раньше extra?['assemblyId'] as int падал NoSuchMethodError,
              // если open происходил по deep link без extra.
              final extra = state.extra as Map<String, dynamic>?;
              final extraAssemblyId = extra?['assemblyId'];
              final queryAssemblyId = int.tryParse(
                state.uri.queryParameters['assemblyId'] ?? '',
              );
              final assemblyId = (extraAssemblyId is int)
                  ? extraAssemblyId
                  : queryAssemblyId;
              if (assemblyId == null) {
                return _adaptivePage(
                  context,
                  state,
                  const _InvalidLinkScreen(
                    reason:
                        'Не указана сборка для трека. '
                        'Откройте трек из карточки сборки.',
                  ),
                );
              }
              return _adaptivePage(
                context,
                state,
                AppScaffold(
                  title: 'Редактирование трека',
                  child: SpTrackEditScreen(trackId: id, assemblyId: assemblyId),
                ),
              );
            },
          ),
        ],
      ),
      // Purchase Blanks routes
      GoRoute(
        name: 'self-buyout',
        path: '/self-buyout',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(title: 'Самовыкуп', child: SelfBuyoutScreen()),
        ),
      ),
      GoRoute(
        name: 'purchase-blanks',
        path: '/purchase-blanks',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adaptivePage(
          context,
          state,
          const AppScaffold(
            title: 'Выкуп по бланку',
            child: PurchaseBlanksScreen(),
          ),
        ),
        routes: [
          GoRoute(
            name: 'purchase-blank-detail',
            path: ':id',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return _adaptivePage(
                context,
                state,
                AppScaffold(
                  title: 'Бланк #$id',
                  child: PurchaseBlankDetailScreen(blankId: id),
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
});

Page<void> _adaptivePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  if (AppLayout.useSideNavigation(context)) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }

  return MaterialPage<void>(key: state.pageKey, child: child);
}

/// Notifier that triggers router refresh when auth state changes
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (_, _) {
      notifyListeners();
    });
    _ref.listen(partnerLinkProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

/// PU-S6/H4: показывается когда роут не смог распарсить параметры
/// (некорректный ID, отсутствует обязательный query). Не падаем ассертом,
/// показываем дружелюбный экран с кнопкой возврата.
class _InvalidLinkScreen extends StatelessWidget {
  const _InvalidLinkScreen({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ссылка недействительна',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                reason,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
