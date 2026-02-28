import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/players_provider.dart';
import '../models/team_membership_info.dart';

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
      // Ensure theme provider knows the current team
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
      // Handle /payments mapping to /tokens
      if (routes[i] == '/tokens' && location.startsWith('/payments')) return i;
    }
    return 0;
  }

  void _showTeamSwitcher() {
    final auth = context.read<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final teams = auth.teams ?? [];
    final currentTeamId = auth.teamId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'I miei Team',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...teams.map((team) {
                  final isActive = team.teamId == currentTeamId;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isActive
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.sports_soccer,
                        color: isActive ? cs.primary : cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      team.teamName,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      team.isAdmin ? 'Amministratore' : 'Giocatore',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    trailing: isActive
                        ? Icon(Icons.check_circle, color: cs.primary)
                        : null,
                    onTap: isActive
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await _switchToTeam(team);
                          },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Icon(Icons.add, color: cs.primary, size: 20),
                  ),
                  title: const Text('Crea nuovo team'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showCreateTeamDialog();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Icon(Icons.link, color: cs.primary, size: 20),
                  ),
                  title: const Text('Unisciti con codice'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showJoinTeamDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchToTeam(TeamMembershipInfo team) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.switchTeam(team.teamId);
    if (success && mounted) {
      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
      _resetAllProviders();
      context.go('/dashboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Errore nel cambio team')),
      );
    }
  }

  void _resetAllProviders() {
    context.read<DashboardProvider>().reset();
    context.read<MatchesProvider>().reset();
    context.read<PlayersProvider>().reset();
    context.read<AnnouncementsProvider>().reset();
  }

  void _showCreateTeamDialog() {
    final nomeTeamCtrl = TextEditingController();
    final nomeGiocatoreCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final partiteCtrl = TextEditingController(text: '8');
    final gettoniCtrl = TextEditingController(text: '4');
    final formKey = GlobalKey<FormState>();
    bool useGettoniValue = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Crea nuovo team'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomeTeamCtrl,
                        decoration: const InputDecoration(labelText: 'Nome Team'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nomeGiocatoreCtrl,
                        decoration: const InputDecoration(labelText: 'Nome Giocatore'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: soprannomeCtrl,
                        decoration: const InputDecoration(labelText: 'Soprannome (opzionale)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: partiteCtrl,
                        decoration: const InputDecoration(labelText: 'Partite per stagione'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Numero valido' : null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Usa sistema gettoni'),
                        subtitle: const Text('Gestione presenze con gettoni'),
                        value: useGettoniValue,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDialogState(() => useGettoniValue = v),
                      ),
                      if (useGettoniValue) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: gettoniCtrl,
                          decoration: const InputDecoration(labelText: 'Gettoni per giocatore'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || int.tryParse(v) == null ? 'Numero valido' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final auth = context.read<AuthProvider>();
                    final success = await auth.createTeam(
                      nomeTeam: nomeTeamCtrl.text.trim(),
                      nomeGiocatore: nomeGiocatoreCtrl.text.trim(),
                      soprannome: soprannomeCtrl.text.trim(),
                      partitePerStagione: int.parse(partiteCtrl.text),
                      gettoniPerGiocatore: useGettoniValue ? int.parse(gettoniCtrl.text) : 0,
                      useGettoni: useGettoniValue,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (success && mounted) {
                      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
                      _resetAllProviders();
                      context.go('/dashboard');
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(auth.error ?? 'Errore nella creazione')),
                      );
                    }
                  },
              child: const Text('Crea'),
            ),
          ],
        );
          },
        );
      },
    );
  }

  void _showJoinTeamDialog() {
    final codeCtrl = TextEditingController();
    final nomeCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Unisciti con codice'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Codice invito'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: soprannomeCtrl,
                    decoration: const InputDecoration(labelText: 'Soprannome (opzionale)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefonoCtrl,
                    decoration: const InputDecoration(labelText: 'Telefono (opzionale)'),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final auth = context.read<AuthProvider>();
                final success = await auth.joinTeam(
                  inviteCode: codeCtrl.text.trim(),
                  nome: nomeCtrl.text.trim(),
                  soprannome: soprannomeCtrl.text.trim(),
                  telefono: telefonoCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (success && mounted) {
                  context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
                  _resetAllProviders();
                  context.go('/dashboard');
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(auth.error ?? 'Errore nell\'unirsi al team')),
                  );
                }
              },
              child: const Text('Unisciti'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final dashProv = context.watch<DashboardProvider>();
    final useGettoni = dashProv.useGettoni;
    final routes = _buildRoutes(useGettoni);
    final cs = Theme.of(context).colorScheme;
    final hasMultipleTeams = auth.teams != null && auth.teams!.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: hasMultipleTeams ? _showTeamSwitcher : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (theme.hasLogo && theme.logoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    theme.logoBytes!,
                    width: 28, height: 28,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(Icons.sports_soccer, size: 22, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                theme.teamName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: cs.onSurface,
                ),
              ),
              if (hasMultipleTeams) ...[
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 20, color: cs.onSurfaceVariant),
              ],
            ],
          ),
        ),
        actions: [
          if (auth.currentPlayer != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.currentPlayer!.soprannome ?? auth.currentPlayer!.nome.split(' ').first,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Impostazioni',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context, routes),
        onDestinationSelected: (index) {
          if (index < routes.length) context.go(routes[index]);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Partite',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Rosa',
          ),
          if (useGettoni)
            const NavigationDestination(
              icon: Icon(Icons.toll_outlined),
              selectedIcon: Icon(Icons.toll),
              label: 'Gettoni',
            ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistiche',
          ),
          NavigationDestination(
            icon: Consumer<AnnouncementsProvider>(
              builder: (context, prov, child) {
                final unread = prov.unreadCount;
                if (unread > 0) {
                  return Badge(
                    label: Text('$unread'),
                    child: const Icon(Icons.campaign_outlined),
                  );
                }
                return const Icon(Icons.campaign_outlined);
              },
            ),
            selectedIcon: const Icon(Icons.campaign),
            label: 'Bacheca',
          ),
        ],
      ),
    );
  }
}
