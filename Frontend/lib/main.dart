import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;

import 'core/navigation/app_page.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/api_client.dart';
import 'core/push/push_manager.dart';
import 'providers/auth_provider.dart';
import 'providers/matches_provider.dart';
import 'providers/players_provider.dart';
import 'providers/convocations_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/tokens_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/announcements_provider.dart';
import 'providers/team_draft_provider.dart';
import 'providers/club_provider.dart';
import 'providers/notifications_provider.dart';
import 'screens/draft_screen.dart';
import 'screens/draft_join_screen.dart';
import 'screens/login_screen.dart';
import 'screens/app_scaffold.dart';
import 'screens/dashboard_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/players_screen.dart';
import 'screens/player_detail_screen.dart';
import 'screens/tokens_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/match_day_screen.dart';
import 'screens/convocations_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/live_match_screen.dart';
import 'screens/bacheca_screen.dart';
import 'screens/team_selection_screen.dart';
import 'screens/club_screen.dart';
import 'screens/join_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BrowserBack.install();
  await initializeDateFormatting('it_IT', null);
  // Space Grotesk e Bebas Neue sono asset del pacchetto (pubspec: assets/google_fonts/):
  // niente FOUT al primo frame, funzionano offline, nessuna chiamata a Google.
  // In debug un peso mancante lancia un'eccezione esplicita: e' voluto.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const InCampoApp());
  WidgetsBinding.instance.addPostFrameCallback((_) => _removeSplash());
}

/// Toglie lo splash HTML di index.html con una dissolvenza, appena Flutter ha
/// disegnato il primo frame (il login su fondo ink: nessun flash bianco).
void _removeSplash() {
  final el = web.document.getElementById('splash');
  if (el == null) return;
  el.classList.add('out');
  Future.delayed(const Duration(milliseconds: 300), () => el.remove());
}

class InCampoApp extends StatefulWidget {
  const InCampoApp({super.key});

  @override
  State<InCampoApp> createState() => _InCampoAppState();
}

class _InCampoAppState extends State<InCampoApp> {
  late final SecureStorageService _storage;
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;
  late final GoRouter _router;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  DateTime? _lastNetworkToast;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _apiClient = ApiClient(storage: _storage);
    _authProvider = AuthProvider(apiClient: _apiClient, storage: _storage);
    _router = _buildRouter();
    // Errore di rete/server: un avviso solo, non uno per ogni chiamata fallita
    _apiClient.onNetworkError = (message) {
      final now = DateTime.now();
      if (_lastNetworkToast != null &&
          now.difference(_lastNetworkToast!) < const Duration(seconds: 6)) {
        return;
      }
      _lastNetworkToast = now;
      _messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ));
    };
    // Sessione scaduta (refresh fallito) → logout pulito + ritorno al login
    _apiClient.onSessionExpired = () async {
      if (!_authProvider.isAuthenticated) return;
      // Senza token valido il server non si puo' avvisare: almeno il browser
      // smette di ricevere (il server ripulisce la subscription al primo 410)
      try {
        await PushManager.unsubscribe();
      } catch (_) {}
      await _authProvider.logout();
      _router.go('/login');
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => MatchesProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => PlayersProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => ConvocationsProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => AttendanceProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => TokensProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementsProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => TeamDraftProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => ClubProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(create: (_) => NotificationsProvider(apiClient: _apiClient)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            scaffoldMessengerKey: _messengerKey,
            title: themeProvider.teamName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.buildTheme(dark: false),
            darkTheme: themeProvider.buildTheme(dark: true),
            themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
            routerConfig: _router,
          );
        },
      ),
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isAuth = _authProvider.isAuthenticated;
        final loc = state.matchedLocation;
        final isLoginRoute = loc == '/login';
        final isSelectTeamRoute = loc == '/select-team';
        final isDraftRoute = loc == '/draft';
        final isJoinRoute = loc.startsWith('/draft/join/');
        // Link di invito squadra/societa': chi non ha ancora una squadra puo' aprirlo
        final isTeamJoin = loc.startsWith('/join/');
        final needsTeamSelection = _authProvider.needsTeamSelection;

        // /draft/join/:code è accessibile anche senza login (lo screen gestisce il redirect a /login)
        if (!isAuth && !isLoginRoute && !isJoinRoute) {
          final next = Uri.encodeQueryComponent(state.uri.toString());
          return '/login?next=$next';
        }
        // Il deep link (link condiviso, QR, notifica) sopravvive al ripristino della
        // sessione: al boot si passa da /login?next=... e, appena il token e' valido,
        // il router tornerebbe in dashboard prima che il login legga `next`.
        final next = state.uri.queryParameters['next'];
        final nextValido = next != null && next.startsWith('/') && !next.startsWith('//');
        if (isAuth && needsTeamSelection && isLoginRoute && nextValido && next.startsWith('/join/')) {
          return next;
        }
        if (isAuth && needsTeamSelection && !isSelectTeamRoute && !isDraftRoute && !isJoinRoute && !isTeamJoin) {
          return '/select-team';
        }
        if (isAuth && !needsTeamSelection && (isLoginRoute || isSelectTeamRoute)) {
          return isLoginRoute && nextValido ? next : '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: const LoginScreen()),
        ),
        GoRoute(
          path: '/select-team',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: const TeamSelectionScreen()),
        ),
        GoRoute(
          path: '/draft',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: DraftScreen(
            initialDraftId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
          )),
        ),
        GoRoute(
          path: '/join/:code',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: JoinScreen(code: state.pathParameters['code']!)),
        ),
        GoRoute(
          path: '/draft/join/:code',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: DraftJoinScreen(code: state.pathParameters['code']!)),
        ),
        ShellRoute(
          pageBuilder: (context, state, child) => AppPage(key: state.pageKey, child: AppScaffold(child: child)),
          routes: [
            GoRoute(path: '/dashboard', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const DashboardScreen())),
            GoRoute(path: '/calendar', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const CalendarScreen())),
            GoRoute(path: '/players', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const PlayersScreen())),
            GoRoute(path: '/tokens', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const TokensScreen())),
            GoRoute(path: '/payments', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const PaymentsScreen())),
            GoRoute(path: '/stats', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const StatsScreen())),
            GoRoute(path: '/bacheca', pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const BachecaScreen())),
          ],
        ),
        GoRoute(
          path: '/club',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: const ClubScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => AppPage(key: state.pageKey, child: const SettingsScreen()),
        ),
        GoRoute(
          path: '/match/:matchId',
          pageBuilder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return AppPage(key: state.pageKey, child: MatchDetailScreen(matchId: matchId));
          },
        ),
        GoRoute(
          path: '/match/:matchId/day',
          pageBuilder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return AppPage(key: state.pageKey, child: MatchDayScreen(matchId: matchId));
          },
        ),
        GoRoute(
          path: '/match/:matchId/live',
          pageBuilder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return AppPage(key: state.pageKey, child: LiveMatchScreen(matchId: matchId));
          },
        ),
        GoRoute(
          path: '/match/:matchId/convocations',
          pageBuilder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return AppPage(key: state.pageKey, child: ConvocationsScreen(matchId: matchId));
          },
        ),
        GoRoute(
          path: '/player/:playerId',
          pageBuilder: (context, state) {
            final playerId = int.parse(state.pathParameters['playerId']!);
            return AppPage(key: state.pageKey, child: PlayerDetailScreen(playerId: playerId));
          },
        ),
      ],
    );
  }
}
