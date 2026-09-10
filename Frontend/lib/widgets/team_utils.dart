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
import 'app_widgets.dart';

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
  final theme = context.read<ThemeProvider>();
  final teams = auth.teams ?? [];
  final currentTeamId = auth.teamId;
  // Con piu' squadre nella stessa societa' il nome da solo non basta a distinguerle:
  // si raggruppa per societa' e si mostra il formato accanto a ognuna.
  final groups = groupTeamsByClub(teams);
  final hasClubs = groups.any((g) => g.clubId != null);

  showAppSheet<void>(
    context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textColor = isDark ? AppTokens.darkText : AppTokens.text;
      final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DisplayText('LE TUE SQUADRE', size: 22, color: textColor),
              const SizedBox(height: 6),
              for (final group in groups) ...[
                if (!group.isSingleTeam || group.clubId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                    child: Eyebrow(group.nome.toUpperCase()),
                  ),
                ...group.teams.map((team) {
                  final isActive = team.teamId == currentTeamId;
                  return InkWell(
                    onTap: isActive
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await switchToTeam(context, team);
                          },
                    borderRadius: BorderRadius.circular(AppTokens.rButton),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        children: [
                          TeamCrest(
                            initials: teamInitials(team.teamName, fallback: '?'),
                            logo: theme.logoBytesForTeam(team.teamId),
                            size: 40,
                            radius: 10,
                            fontSize: 18,
                            bg: isActive ? AppTokens.brand : AppTokens.ink,
                            fg: isActive ? AppTokens.brandInk : AppTokens.brand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        team.teamName,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FormatBadge(
                                      team.formato,
                                      tone: FormatBadgeTone.soft,
                                      fontSize: 10,
                                    ),
                                  ],
                                ),
                                Text(
                                  team.isAdmin ? 'Amministratore' : 'Giocatore',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isActive ? Icons.check_circle : Icons.chevron_right,
                            size: 20,
                            color: isActive
                                ? (isDark ? AppTokens.darkBrand : AppTokens.brand)
                                : muteColor,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (hasClubs) ...[
                const Divider(height: 24),
                AppSheetAction(
                  icon: Icons.shield_outlined,
                  label: 'Gestisci societa',
                  subtitle: 'Squadre, anagrafica condivisa, codice invito',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.go('/club');
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
