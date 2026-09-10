import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/team_draft_provider.dart';
import '../providers/theme_provider.dart';
import '../models/team_draft.dart';
import '../models/team_membership_info.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_mark.dart';

class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  bool _isSelecting = false;
  int? _selectedTeamId;
  bool _draftsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_draftsLoaded) {
      _draftsLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TeamDraftProvider>().loadDrafts();
      });
    }
  }

  void _openDraft(TeamDraft draft) {
    context.read<TeamDraftProvider>().selectDraft(draft.id);
    context.go('/draft?id=${draft.id}');
  }

  Future<void> _confirm() async {
    final teamId = _selectedTeamId;
    if (teamId == null || _isSelecting) return;
    setState(() => _isSelecting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.selectTeam(teamId);
    if (success && mounted) {
      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
      context.go('/dashboard');
    } else if (mounted) {
      setState(() => _isSelecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Errore nella selezione')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final teams = auth.teams ?? [];

    return Scaffold(
      backgroundColor: AppTokens.ink,
      body: Stack(
        children: [
          const GlowSpot(top: -180, left: -140, size: 480, opacity: 0.22),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandWordmark(markSize: 28),
                      const SizedBox(height: 28),
                      const Eyebrow('I TUOI TEAM', color: AppTokens.brand),
                      const SizedBox(height: 12),
                      const DisplayText(
                        'SCEGLI\nLA SQUADRA',
                        size: 44,
                        height: 0.95,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<TeamDraftProvider>(
                    builder: (context, draftProvider, _) {
                      final drafts = draftProvider.drafts;
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Con piu squadre nella stessa societa il nome non basta:
                          // si raggruppa e si mostra il formato su ogni riga.
                          ...groupTeamsByClub(teams).expand((group) => [
                                if (group.clubId != null && !group.isSingleTeam)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                                    child: Eyebrow(group.nome.toUpperCase(), onInk: true),
                                  ),
                                ...group.teams.map((t) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _TeamTile(
                                        team: t,
                                        selected: _selectedTeamId == t.teamId,
                                        onTap: () => setState(
                                            () => _selectedTeamId = t.teamId),
                                      ),
                                    )),
                              ]),
                          if (drafts.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Eyebrow('I MIEI DRAFT · ${drafts.length}', color: AppTokens.brand),
                                  if (draftProvider.isLoading)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppTokens.brand,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...drafts.map((d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _DraftTile(
                                    draft: d,
                                    onTap: () => _openDraft(d),
                                  ),
                                )),
                          ],
                          const SizedBox(height: 8),
                          AppCard(
                            onInk: true,
                            radius: 16,
                            borderColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            onTap: _showCreateOrJoin,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Crea o unisciti a team',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _selectedTeamId != null && !_isSelecting ? _confirm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.brand,
                        foregroundColor: AppTokens.brandInk,
                        disabledBackgroundColor: AppTokens.brand.withOpacity(0.3),
                        disabledForegroundColor: AppTokens.brandInk.withOpacity(0.7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: _isSelecting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTokens.brandInk,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Entra'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateOrJoin() {
    showAppSheet<void>(
      context,
      onInk: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetAction(
            icon: Icons.tune,
            label: 'Pianifica con il configuratore',
            subtitle: 'Costruisci la rosa con stati e voti prima di lanciarla',
            onInk: true,
            onTap: () {
              Navigator.pop(ctx);
              context.go('/draft');
            },
          ),
          AppSheetAction(
            icon: Icons.add_circle_outline,
            label: 'Crea nuovo team',
            onInk: true,
            onTap: () {
              Navigator.pop(ctx);
              _showCreateTeamDialog();
            },
          ),
          AppSheetAction(
            icon: Icons.link,
            label: 'Unisciti con codice',
            onInk: true,
            onTap: () {
              Navigator.pop(ctx);
              _showJoinTeamDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showCreateTeamDialog() {
    final nomeTeamCtrl = TextEditingController();
    final nomeGiocatoreCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final partiteCtrl = TextEditingController(text: '8');
    final gettoniCtrl = TextEditingController(text: '4');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomeGiocatoreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nome Giocatore'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: soprannomeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Soprannome'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: partiteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Partite per stagione'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: gettoniCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Gettoni per giocatore'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final auth = context.read<AuthProvider>();
              final success = await auth.createTeam(
                nomeTeam: nomeTeamCtrl.text.trim(),
                nomeGiocatore: nomeGiocatoreCtrl.text.trim(),
                soprannome: soprannomeCtrl.text.trim(),
                partitePerStagione: int.tryParse(partiteCtrl.text) ?? 8,
                gettoniPerGiocatore: int.tryParse(gettoniCtrl.text) ?? 4,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (success && mounted) {
                context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
                context.go('/dashboard');
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog() {
    final codeCtrl = TextEditingController();
    final nomeCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool checking = false;
    bool checked = false;
    String? teamName;
    List<dynamic> pending = [];
    int? selectedPendingId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> verifica() async {
            if (codeCtrl.text.trim().isEmpty) return;
            setLocal(() => checking = true);
            final info = await context.read<AuthProvider>().getJoinInfo(codeCtrl.text.trim());
            setLocal(() {
              checking = false;
              checked = true;
              teamName = info?['teamName'] as String?;
              pending = (info?['pendingPlayers'] as List?) ?? [];
              selectedPendingId = null;
            });
          }

          return AlertDialog(
            title: const Text('Unisciti con codice'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Codice invito'),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        checking
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : TextButton(onPressed: verifica, child: const Text('Verifica')),
                      ],
                    ),
                    if (checked && teamName != null) ...[
                      const SizedBox(height: 8),
                      Text('Team: $teamName',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Sei uno di questi? (opzionale)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),
                      AppChoiceChips<int>(
                        values: pending.map<int>((p) => p['id'] as int).toList(),
                        selected: selectedPendingId,
                        allowNull: true,
                        spacing: 6,
                        label: (id) =>
                            pending.firstWhere((p) => p['id'] == id)['nome'] as String,
                        onChanged: (id) => setLocal(() {
                          if (id == null) {
                            selectedPendingId = null;
                            return;
                          }
                          final p = pending.firstWhere((p) => p['id'] == id);
                          selectedPendingId = id;
                          nomeCtrl.text = p['nome'] as String;
                          if (p['soprannome'] != null) {
                            soprannomeCtrl.text = p['soprannome'] as String;
                          }
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: soprannomeCtrl,
                      decoration: const InputDecoration(labelText: 'Soprannome'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefonoCtrl,
                      decoration: const InputDecoration(labelText: 'Telefono'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annulla')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final auth = context.read<AuthProvider>();
                  final success = await auth.joinTeam(
                    inviteCode: codeCtrl.text.trim(),
                    nome: nomeCtrl.text.trim(),
                    soprannome: soprannomeCtrl.text.trim(),
                    telefono: telefonoCtrl.text.trim(),
                    pendingPlayerId: selectedPendingId,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (success && mounted) {
                    context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
                    context.go('/dashboard');
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(auth.error ?? 'Errore')),
                    );
                  }
                },
                child: const Text('Unisciti'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  final TeamMembershipInfo team;
  final bool selected;
  final VoidCallback onTap;

  const _TeamTile({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = teamInitials(team.teamName, fallback: '?');
    return AppCard(
      onInk: true,
      padding: const EdgeInsets.all(18),
      color: selected ? AppTokens.brand.withOpacity(0.08) : null,
      borderColor: selected ? AppTokens.brand : null,
      borderWidth: selected ? 1.5 : 1,
      onTap: onTap,
      child: Row(
          children: [
            TeamCrest(
              initials: initials,
              logo: context.watch<ThemeProvider>().logoBytesForTeam(team.teamId),
              size: 52,
              radius: 14,
              fontSize: 20,
              bg: selected ? AppTokens.brand : Colors.white.withOpacity(0.1),
              fg: selected ? AppTokens.brandInk : Colors.white,
            ),
            const SizedBox(width: 14),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FormatBadge(
                        team.formato,
                        tone: selected ? FormatBadgeTone.brand : FormatBadgeTone.onInk,
                        fontSize: 11,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      team.formatoLabel,
                      team.isAdmin ? 'Amministratore' : 'Giocatore',
                    ].join(' · '),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            selected
                ? const Icon(Icons.check_circle, color: AppTokens.brand, size: 22)
                : Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.4), size: 18),
          ],
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final TeamDraft draft;
  final VoidCallback onTap;

  const _DraftTile({required this.draft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final confermati = draft.countByStatus(DraftStatus.confermato);
    final initials = teamInitials(draft.nomeTeam, fallback: '?');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.brand.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTokens.brand.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTokens.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Text(
                    initials,
                    style: GoogleFonts.bebasNeue(fontSize: 22, color: AppTokens.brandInk),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTokens.ink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.tune, size: 11, color: AppTokens.brand),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          draft.nomeTeam,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AppChip(
                        text: draft.isOwner ? 'OWNER' : 'EDITOR',
                        variant: draft.isOwner ? AppChipVariant.brand : AppChipVariant.dark,
                        onInk: true,
                        fontSize: 9,
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$confermati confermati • '
                    '${draft.candidates.length} candidati • '
                    '${draft.collaborators.length} ${draft.collaborators.length == 1 ? "membro" : "membri"}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }
}
