import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/club_provider.dart';
import '../providers/announcements_provider.dart';
import '../widgets/app_widgets.dart';

class AppScaffold extends StatefulWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _teamsLoaded = false;
  int? _syncedTeamId;

  /// Nome e logo della squadra vengono dal server: prima la top bar diceva
  /// "InCampo" finche' qualcuno non riscriveva il nome nel proprio browser.
  Future<void> _syncBrand(int teamId) async {
    final auth = context.read<AuthProvider>();
    final theme = context.read<ThemeProvider>();
    if (theme.currentTeamId != teamId) await theme.setCurrentTeamId(teamId);
    final membership = auth.teams?.where((t) => t.teamId == teamId).firstOrNull;
    if (membership != null) {
      await theme.syncFromServer(teamId: teamId, teamName: membership.teamName);
    }
    final cfg = await context.read<ClubProvider>().loadTeamConfig(teamId);
    if (!mounted || cfg == null) return;
    await theme.syncFromServer(teamId: teamId, teamName: cfg.nome, logoBase64: cfg.logoBase64, syncLogo: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_teamsLoaded) {
      _teamsLoaded = true;
      final auth = context.read<AuthProvider>();
      if (auth.teams == null) {
        auth.loadMyTeams();
      }
      final themeProvider = context.read<ThemeProvider>();
      if (auth.teamId != 0 && themeProvider.currentTeamId != auth.teamId) {
        themeProvider.setCurrentTeamId(auth.teamId);
      }
    }
  }

  List<String> _buildRoutes(bool useGettoni) {
    return [
      '/dashboard',
      '/calendar',
      '/players',
      if (useGettoni) '/tokens',
      '/stats',
      '/bacheca',
    ];
  }

  int _currentIndex(BuildContext context, List<String> routes) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < routes.length; i++) {
      if (location.startsWith(routes[i])) return i;
      if (routes[i] == '/tokens' && location.startsWith('/payments')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.teamId != 0 && auth.teamId != _syncedTeamId) {
      _syncedTeamId = auth.teamId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncBrand(auth.teamId);
      });
    }
    final dashProv = context.watch<DashboardProvider>();
    final useGettoni = dashProv.useGettoni;
    final routes = _buildRoutes(useGettoni);
    final activeIndex = _currentIndex(context, routes);

    final tabs = <AppTab>[
      const AppTab(Icons.home_outlined, 'Home'),
      const AppTab(Icons.calendar_today_outlined, 'Partite'),
      const AppTab(Icons.groups_outlined, 'Rosa'),
      if (useGettoni) const AppTab(Icons.toll_outlined, 'Gettoni'),
      const AppTab(Icons.bar_chart_outlined, 'Stats'),
      AppTab(
        Icons.campaign_outlined,
        'Bacheca',
        badge: Consumer<AnnouncementsProvider>(
          builder: (context, prov, _) {
            if (prov.unreadCount <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTokens.bad,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
              alignment: Alignment.center,
              child: Text(
                '${prov.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTokens.darkPaper : AppTokens.paper;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: paper,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: widget.child,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: AppTabBar(
          activeIndex: activeIndex,
          onTap: (i) {
            if (i < routes.length) context.go(routes[i]);
          },
          tabs: tabs,
        ),
      ),
    );
  }
}
