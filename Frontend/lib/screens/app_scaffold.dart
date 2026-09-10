import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/announcements_provider.dart';
import '../widgets/gimmy_widgets.dart';

class AppScaffold extends StatefulWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _teamsLoaded = false;

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
    final dashProv = context.watch<DashboardProvider>();
    final useGettoni = dashProv.useGettoni;
    final routes = _buildRoutes(useGettoni);
    final activeIndex = _currentIndex(context, routes);

    final tabs = <GimmyTab>[
      const GimmyTab(Icons.home_outlined, 'Home'),
      const GimmyTab(Icons.calendar_today_outlined, 'Partite'),
      const GimmyTab(Icons.groups_outlined, 'Rosa'),
      if (useGettoni) const GimmyTab(Icons.toll_outlined, 'Gettoni'),
      const GimmyTab(Icons.bar_chart_outlined, 'Stats'),
      GimmyTab(
        Icons.campaign_outlined,
        'Bacheca',
        badge: Consumer<AnnouncementsProvider>(
          builder: (context, prov, _) {
            if (prov.unreadCount <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: GimmyTokens.bad,
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
    final paper = isDark ? GimmyTokens.darkPaper : GimmyTokens.paper;
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
        child: GimmyTabBar(
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
