import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/club_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/players_provider.dart';
import '../models/team_membership_info.dart';

void _resetProviders(BuildContext context) {
  context.read<DashboardProvider>().reset();
  context.read<MatchesProvider>().reset();
  context.read<PlayersProvider>().reset();
  context.read<AnnouncementsProvider>().reset();
  // La configurazione caricata appartiene alla squadra precedente
  context.read<ClubProvider>().reset();
}

Future<void> switchToTeam(BuildContext context, TeamMembershipInfo team) async {
  final auth = context.read<AuthProvider>();
  final success = await auth.switchTeam(team.teamId);
  if (success && context.mounted) {
    context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
    _resetProviders(context);
    context.go('/dashboard');
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Errore nel cambio team')),
    );
  }
}

void showTeamSwitcher(BuildContext context) {
  final auth = context.read<AuthProvider>();
  final teams = auth.teams ?? [];
  final currentTeamId = auth.teamId;
  final cs = Theme.of(context).colorScheme;
  // Con piu' squadre nella stessa societa' il nome da solo non basta a distinguerle:
  // si raggruppa per societa' e si mostra il formato accanto a ognuna.
  final groups = groupTeamsByClub(teams);
  final hasClubs = groups.any((g) => g.clubId != null);

  showModalBottomSheet(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'LE TUE SQUADRE',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        letterSpacing: 0.02 * 22,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final group in groups) ...[
                  if (!group.isSingleTeam || group.clubId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          group.nome.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ...group.teams.map((team) {
                    final isActive = team.teamId == currentTeamId;
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isActive ? cs.primary : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          team.formatoShortLabel,
                          style: GoogleFonts.bebasNeue(
                            fontSize: 16,
                            color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(
                        team.teamName,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${team.formatoLabel} · ${team.isAdmin ? 'Amministratore' : 'Giocatore'}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      trailing: isActive
                          ? Icon(Icons.check_circle, color: cs.primary)
                          : const Icon(Icons.chevron_right),
                      onTap: isActive
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              await switchToTeam(context, team);
                            },
                    );
                  }),
                ],
                if (hasClubs) ...[
                  const Divider(height: 24),
                  ListTile(
                    leading: Icon(Icons.shield_outlined, color: cs.onSurfaceVariant),
                    title: const Text('Gestisci societa'),
                    subtitle: Text(
                      'Squadre, anagrafica condivisa, codice invito',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.go('/club');
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
