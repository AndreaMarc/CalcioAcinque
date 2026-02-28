import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/storage/secure_storage.dart';
import 'core/network/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/matches_provider.dart';
import 'providers/players_provider.dart';
import 'providers/convocations_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/tokens_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/announcements_provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  runApp(const CalcioAcinqueApp());
}

class CalcioAcinqueApp extends StatefulWidget {
  const CalcioAcinqueApp({super.key});

  @override
  State<CalcioAcinqueApp> createState() => _CalcioAcinqueAppState();
}

class _CalcioAcinqueAppState extends State<CalcioAcinqueApp> {
  late final SecureStorageService _storage;
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _apiClient = ApiClient(storage: _storage);
    _authProvider = AuthProvider(apiClient: _apiClient, storage: _storage);
    _router = _buildRouter();
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: themeProvider.teamName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.buildTheme(),
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
        final isLoginRoute = state.matchedLocation == '/login';
        final isSelectTeamRoute = state.matchedLocation == '/select-team';
        final needsTeamSelection = _authProvider.needsTeamSelection;

        if (!isAuth && !isLoginRoute) return '/login';
        if (isAuth && needsTeamSelection && !isSelectTeamRoute) return '/select-team';
        if (isAuth && !needsTeamSelection && (isLoginRoute || isSelectTeamRoute)) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/select-team',
          builder: (context, state) => const TeamSelectionScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => AppScaffold(child: child),
          routes: [
            GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
            GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
            GoRoute(path: '/players', builder: (context, state) => const PlayersScreen()),
            GoRoute(path: '/tokens', builder: (context, state) => const TokensScreen()),
            GoRoute(path: '/payments', builder: (context, state) => const PaymentsScreen()),
            GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
            GoRoute(path: '/bacheca', builder: (context, state) => const BachecaScreen()),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/match/:matchId',
          builder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return MatchDetailScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/match/:matchId/day',
          builder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return MatchDayScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/match/:matchId/live',
          builder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return LiveMatchScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/match/:matchId/convocations',
          builder: (context, state) {
            final matchId = int.parse(state.pathParameters['matchId']!);
            return ConvocationsScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/player/:playerId',
          builder: (context, state) {
            final playerId = int.parse(state.pathParameters['playerId']!);
            return PlayerDetailScreen(playerId: playerId);
          },
        ),
      ],
    );
  }
}
