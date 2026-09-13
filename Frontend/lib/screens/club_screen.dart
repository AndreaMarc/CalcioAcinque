import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/club_model.dart';
import '../models/team_draft.dart' show PlayerPosition, PlayerPositionX;
import '../models/ruoli.dart';
import '../models/team_format.dart';
import '../providers/auth_provider.dart';
import '../providers/club_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/payment_links.dart';
import '../widgets/team_utils.dart';
import '../widgets/invite_dialog.dart';

/// Vista di società': elenca le squadre (a 5, a 7, ...) e l'anagrafica condivisa,
/// da cui una stessa persona si iscrive a piu' squadre con regole e costi diversi.
class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  bool _soloCondivisi = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final club = context.read<ClubProvider>();
    if (auth.teams == null) await auth.loadMyTeams();
    await club.loadFormats();
    await club.loadClubs(preferClubId: auth.currentClubId);
    final selected = club.selectedClub;
    if (selected != null) await club.loadMembers(selected.id);
  }

  Future<void> _reloadMembers() async {
    final club = context.read<ClubProvider>();
    final selected = club.selectedClub;
    if (selected != null) await club.loadMembers(selected.id);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTokens.bad : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final club = context.watch<ClubProvider>();
    final theme = context.watch<ThemeProvider>();
    final selected = club.selectedClub;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              teamInitials: teamInitials(selected?.nome ?? theme.teamName, fallback: 'SC'),
              showTeamLogo: false,
              title: 'Societa',
              subtitle: selected?.nome ?? 'Nessuna società',
              onBack: () => context.go('/dashboard'),
              actions: [
                if (selected != null && selected.isAdmin)
                  AppTopBar.iconAction(
                    context,
                    Icons.qr_code_2,
                    () => _showInviteCode(selected),
                  ),
              ],
            ),
            Expanded(
              child: club.isLoading && selected == null
                  ? const Center(child: CircularProgressIndicator())
                  : selected == null
                      ? _EmptyState(onCreate: _showCreateClubDialog, error: club.error)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 32),
                            children: [
                              if (club.clubs.length > 1)
                                _ClubSwitcher(
                                  clubs: club.clubs,
                                  selectedId: selected.id,
                                  onSelect: (id) async {
                                    club.selectClub(id);
                                    await club.loadMembers(id);
                                  },
                                ),
                              _TeamsSection(
                                club: selected,
                                onAddTeam: () => _showCreateTeamDialog(selected),
                                onOpenTeam: _openTeam,
                              ),
                              if (selected.isAdmin)
                                _ClubPaymentSection(
                                  club: selected,
                                  onEdit: () => _showPaymentDialog(selected),
                                ),
                              SectionHead(
                                title: 'Anagrafica società',
                                more: selected.isAdmin ? '+ Aggiungi' : null,
                                onMore: selected.isAdmin
                                    ? () => _showMemberDialog(selected, null)
                                    : null,
                              ),
                              _MembersFilters(
                                soloCondivisi: _soloCondivisi,
                                onToggleCondivisi: (v) => setState(() => _soloCondivisi = v),
                                onSearch: (v) => setState(() => _search = v),
                                totale: selected.totaleMembri,
                              ),
                              ..._buildMembers(club, selected),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMembers(ClubProvider club, ClubModel selected) {
    var members = club.members;
    if (_soloCondivisi) members = members.where((m) => m.condiviso).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      members = members
          .where((m) =>
              m.nome.toLowerCase().contains(q) ||
              (m.soprannome ?? '').toLowerCase().contains(q))
          .toList();
    }

    if (club.isLoading && members.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      ];
    }

    if (members.isEmpty) {
      return [
        EmptyState(
          icon: _soloCondivisi ? Icons.people_outline : Icons.badge_outlined,
          title: _soloCondivisi ? 'NESSUNO IN COMUNE' : 'ANAGRAFICA VUOTA',
          message: _soloCondivisi
              ? 'Nessuno gioca in piu di una squadra.'
              : 'Aggiungi le persone della società e poi iscrivile alle squadre.',
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        )
      ];
    }

    return members
        .map((m) => _MemberCard(
              member: m,
              canManage: selected.isAdmin,
              onEdit: () => _showMemberDialog(selected, m),
              onEnroll: () => _showEnrollSheet(selected, m),
              onUnenroll: (teamId) => _unenroll(selected, m, teamId),
              onDelete: () => _confirmDeleteMember(selected, m),
              onOpenTeam: _openTeam,
            ))
        .toList();
  }

  Future<void> _openTeam(int teamId) async {
    final auth = context.read<AuthProvider>();
    final membership = (auth.teams ?? []).where((t) => t.teamId == teamId).toList();
    if (membership.isEmpty) {
      _toast('Non fai parte di questa squadra: iscriviti dall\'anagrafica', error: true);
      return;
    }
    await switchToTeam(context, membership.first);
  }

  // ------------------------------------------------------------------ dialoghi

  Future<void> _showInviteCode(ClubModel club) async {
    final provider = context.read<ClubProvider>();
    final code = club.inviteCode ?? await provider.loadInviteCode(club.id);
    if (!mounted || code == null) return;
    await showInviteDialog(
      context,
      code: code,
      titolo: 'Invita nella società',
      nome: club.nome,
      descrizione: 'Chi usa questo codice entra nella società e sceglie a quale squadra unirsi.',
    );
  }

  /// PayPal e IBAN della societa: sono il default per tutte le sue squadre.
  Future<void> _showPaymentDialog(ClubModel club) async {
    final provider = context.read<ClubProvider>();
    final paypalCtrl = TextEditingController(text: club.paypalLink ?? '');
    final ibanCtrl = TextEditingController(text: club.iban ?? '');
    final intestatarioCtrl = TextEditingController(text: club.intestatarioIban ?? '');
    var busy = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Dati di pagamento'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Valgono per tutte le squadre della società. Una singola squadra '
                    'puo sovrascriverli dalle sue impostazioni.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paypalCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Link PayPal',
                      hintText: 'https://paypal.me/tuonome',
                    ),
                  ),
                  TextField(
                    controller: ibanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IBAN',
                      hintText: 'IT60 X054 2811 1010 0000 0123 456',
                    ),
                  ),
                  TextField(
                    controller: intestatarioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Intestatario del conto',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setDialogState(() => busy = true);
                        final ok = await provider.updateClub(
                          club.id,
                          // Stringa vuota = cancella il dato
                          paypalLink: paypalCtrl.text.trim(),
                          iban: ibanCtrl.text.trim(),
                          intestatarioIban: intestatarioCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        setDialogState(() => busy = false);
                        if (ok) {
                          Navigator.of(ctx).pop(true);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(provider.error ?? 'Errore')),
                          );
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) _toast('Dati di pagamento aggiornati');
  }

  Future<void> _showCreateClubDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crea società'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome società'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Crea')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;

    final provider = context.read<ClubProvider>();
    if (await provider.createClub(ctrl.text.trim())) {
      _toast('Societa creata');
      await _load();
    } else {
      _toast(provider.error ?? 'Errore', error: true);
    }
  }

  Future<void> _showCreateTeamDialog(ClubModel club) async {
    final provider = context.read<ClubProvider>();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TeamFormDialog(
        title: 'Nuova squadra in ${club.nome}',
        formats: provider.formats,
        onSubmit: (form) => provider.createTeam(
          clubId: club.id,
          nome: form.nome,
          formato: form.formato,
          partitePerStagione: form.partitePerStagione,
          useGettoni: form.useGettoni,
          gettoniPerGiocatore: form.gettoniPerGiocatore,
          quotaIscrizione: form.quotaIscrizione,
          quotaTesseramento: form.quotaTesseramento,
          costoPartita: form.costoPartita,
        ),
        errorOf: () => provider.error,
      ),
    );

    if (created == true && mounted) {
      _toast('Squadra creata');
      // La nuova squadra e' anche una nuova membership: ricarico i team dell'utente
      await context.read<AuthProvider>().loadMyTeams();
      await _load();
    }
  }

  Future<void> _showMemberDialog(ClubModel club, ClubMember? member) async {
    final provider = context.read<ClubProvider>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MemberFormDialog(
        member: member,
        onSubmit: (form) => provider.upsertMember(
          clubId: club.id,
          memberId: member?.id,
          nome: form.nome,
          soprannome: form.soprannome,
          telefono: form.telefono,
          note: form.note,
          email: form.email,
          password: form.password,
        ),
        errorOf: () => provider.error,
      ),
    );
    if (saved == true) _toast(member == null ? 'Anagrafica creata' : 'Anagrafica aggiornata');
  }

  Future<void> _confirmDeleteMember(ClubModel club, ClubMember member) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminare ${member.nome}?',
      message: 'La persona viene rimossa dall\'anagrafica della società. '
          'Funziona solo se non e iscritta a nessuna squadra.',
      confirmLabel: 'Elimina',
      destructive: true,
    );
    if (!ok) return;

    final provider = context.read<ClubProvider>();
    if (await provider.deleteMember(club.id, member.id)) {
      _toast('Anagrafica eliminata');
    } else {
      _toast(provider.error ?? 'Errore', error: true);
    }
  }

  Future<void> _unenroll(ClubModel club, ClubMember member, int teamId) async {
    final squadra = member.squadre.firstWhere((s) => s.teamId == teamId);
    final ok = await showConfirmDialog(
      context,
      title: 'Togliere ${member.nome} da ${squadra.teamNome}?',
      message: 'Vengono perse convocazioni, presenze e gettoni di quella squadra. '
          'La persona resta nell\'anagrafica e nelle altre squadre.',
      confirmLabel: 'Rimuovi',
      destructive: true,
    );
    if (!ok) return;

    final provider = context.read<ClubProvider>();
    final done = await provider.unenrollMember(
      clubId: club.id,
      memberId: member.id,
      teamId: teamId,
    );
    if (done) {
      await context.read<AuthProvider>().loadMyTeams();
      _toast('Rimosso da ${squadra.teamNome}');
    } else {
      _toast(provider.error ?? 'Errore', error: true);
    }
  }

  Future<void> _showEnrollSheet(ClubModel club, ClubMember member) async {
    final provider = context.read<ClubProvider>();
    final disponibili =
        club.squadre.where((t) => !member.giocaIn(t.id)).toList();

    if (!member.haAccount) {
      _toast(
        'Aggiungi email e password all\'anagrafica di ${member.nome} per poterla iscrivere',
        error: true,
      );
      return;
    }
    if (disponibili.isEmpty) {
      _toast('${member.nome} è già in tutte le squadre della società');
      return;
    }

    final done = await showAppSheet<bool>(
      context,
      scrollControlled: true,
      padding: EdgeInsets.zero,
      builder: (ctx) => _EnrollSheet(
        member: member,
        squadre: disponibili,
        positionsFor: provider.positionsFor,
        onSubmit: (teamId, ruolo, posizione, numero) => provider.enrollMember(
          clubId: club.id,
          memberId: member.id,
          teamId: teamId,
          ruolo: ruolo,
          posizione: posizione,
          numeroMaglia: numero,
        ),
        errorOf: () => provider.error,
      ),
    );

    if (done == true && mounted) {
      await context.read<AuthProvider>().loadMyTeams();
      await _reloadMembers();
      _toast('${member.nome} iscritto');
    }
  }
}

// ===================================================================== sezioni

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final String? error;
  const _EmptyState({required this.onCreate, this.error});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.shield_outlined,
      title: 'NESSUNA SOCIETÀ',
      message: 'Una società raggruppa più squadre (per esempio una a 5 e una a 7) '
          'che condividono i giocatori ma hanno regole e costi propri.'
          '${error != null ? '\n\n$error' : ''}',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('Crea società'),
      ),
    );
  }
}

class _ClubSwitcher extends StatelessWidget {
  final List<ClubModel> clubs;
  final int selectedId;
  final ValueChanged<int> onSelect;

  const _ClubSwitcher({
    required this.clubs,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: AppChoiceChips<int>(
        values: clubs.map((c) => c.id).toList(),
        selected: selectedId,
        label: (id) => clubs.firstWhere((c) => c.id == id).nome,
        onChanged: (id) => onSelect(id!),
      ),
    );
  }
}

class _TeamsSection extends StatelessWidget {
  final ClubModel club;
  final VoidCallback onAddTeam;
  final ValueChanged<int> onOpenTeam;

  const _TeamsSection({
    required this.club,
    required this.onAddTeam,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHead(
          title: 'Squadre',
          more: club.isAdmin ? '+ Nuova' : null,
          onMore: club.isAdmin ? onAddTeam : null,
        ),
        if (club.squadre.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Nessuna squadra: creane una scegliendo il formato (a 5, a 7, ...).',
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muteColor),
            ),
          )
        else
          ...club.squadre.map((t) => AppCard(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.all(14),
                onTap: t.mioPlayerId != null ? () => onOpenTeam(t.id) : null,
                child: Row(
                  children: [
                    TeamCrest(
                      initials: teamInitials(t.nome, fallback: 'SQ'),
                      logo: context.watch<ThemeProvider>().logoBytesForTeam(t.id),
                      size: 42,
                      radius: 12,
                      fontSize: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.nome,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${t.totaleGiocatori} in rosa · ${t.giocatoriInCampo} in campo',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
                          ),
                        ],
                      ),
                    ),
                    FormatBadge(t.formato, tone: FormatBadgeTone.soft),
                    if (t.mioPlayerId != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.chevron_right, size: 20, color: muteColor),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('non iscritto',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor)),
                      ),
                  ],
                ),
              )),
      ],
    );
  }
}

/// Dati per farsi pagare, a livello società.
class _ClubPaymentSection extends StatelessWidget {
  final ClubModel club;
  final VoidCallback onEdit;

  const _ClubPaymentSection({required this.club, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final haDati = (club.paypalLink != null && club.paypalLink!.isNotEmpty) ||
        (club.iban != null && club.iban!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHead(title: 'Come farsi pagare', more: 'Modifica', onMore: onEdit),
        AppCard(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          padding: const EdgeInsets.all(14),
          child: haDati
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (club.paypalLink != null && club.paypalLink!.isNotEmpty) ...[
                      const Eyebrow('PAYPAL'),
                      const SizedBox(height: 2),
                      SelectableText(club.paypalLink!,
                          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: textColor)),
                      const SizedBox(height: 10),
                    ],
                    if (club.iban != null && club.iban!.isNotEmpty) ...[
                      const Eyebrow('IBAN'),
                      const SizedBox(height: 2),
                      SelectableText(club.iban!,
                          style: TextStyle(
                              fontSize: 13, letterSpacing: 0.4, fontFamily: 'monospace', color: textColor)),
                      if (club.intestatarioIban != null && club.intestatarioIban!.isNotEmpty)
                        Text(club.intestatarioIban!,
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor)),
                      const SizedBox(height: 10),
                    ],
                    PaymentLinks(
                      paypalLink: club.paypalLink,
                      iban: club.iban,
                      intestatario: club.intestatarioIban,
                      compatto: true,
                    ),
                  ],
                )
              : Text(
                  'Non hai ancora messo PayPal o IBAN: senza quelli i giocatori '
                  'ricevono la notifica ma non sanno dove pagare.',
                  style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
                ),
        ),
      ],
    );
  }
}

class _MembersFilters extends StatelessWidget {
  final bool soloCondivisi;
  final ValueChanged<bool> onToggleCondivisi;
  final ValueChanged<String> onSearch;
  final int totale;

  const _MembersFilters({
    required this.soloCondivisi,
    required this.onToggleCondivisi,
    required this.onSearch,
    required this.totale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onSearch,
            style: GoogleFonts.spaceGrotesk(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Cerca tra $totale persone',
            ),
          ),
          const SizedBox(height: 10),
          AppChoiceChips<bool>(
            values: const [false, true],
            selected: soloCondivisi,
            label: (v) => v ? 'Solo condivisi tra squadre' : 'Tutti',
            onChanged: (v) => onToggleCondivisi(v ?? false),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final ClubMember member;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onEnroll;
  final ValueChanged<int> onUnenroll;
  final VoidCallback onDelete;
  final ValueChanged<int> onOpenTeam;

  const _MemberCard({
    required this.member,
    required this.canManage,
    required this.onEdit,
    required this.onEnroll,
    required this.onUnenroll,
    required this.onDelete,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return AppCard(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CrestBox(initials: teamInitials(member.nome, fallback: '?'), size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (member.condiviso) ...[
                            const SizedBox(width: 6),
                            const AppChip(text: 'condiviso', variant: AppChipVariant.ok),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email ?? 'senza account',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: member.haAccount ? muteColor : AppTokens.bad,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'enroll':
                          onEnroll();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Modifica anagrafica')),
                      const PopupMenuItem(value: 'enroll', child: Text('Iscrivi a una squadra')),
                      const PopupMenuItem(value: 'delete', child: Text('Elimina')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (member.squadre.isEmpty)
              Text(
                'Non iscritto a nessuna squadra',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: member.squadre
                    .map((s) => _TeamBadge(
                          squadra: s,
                          canManage: canManage,
                          onRemove: () => onUnenroll(s.teamId),
                          onOpen: () => onOpenTeam(s.teamId),
                        ))
                    .toList(),
              ),
          ],
        ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final ClubMemberTeam squadra;
  final bool canManage;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  const _TeamBadge({
    required this.squadra,
    required this.canManage,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final dettagli = [
      squadra.formato.shortLabel,
      if (squadra.posizione != null) squadra.posizione!.shortLabel,
      if (squadra.numeroMaglia != null) '#${squadra.numeroMaglia}',
      if (squadra.isAdmin) 'admin',
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTokens.ink3 : AppTokens.paperLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppTokens.darkLine : AppTokens.line),
        ),
        padding: EdgeInsets.fromLTRB(10, 6, canManage ? 4 : 10, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(squadra.teamNome,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                Text(dettagli, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: muteColor)),
              ],
            ),
            if (canManage)
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: 'Rimuovi dalla squadra',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== dialoghi

class TeamFormValues {
  final String nome;
  final TeamFormat formato;
  final int partitePerStagione;
  final bool useGettoni;
  final int gettoniPerGiocatore;
  final double quotaIscrizione;
  final double quotaTesseramento;
  final double costoPartita;

  TeamFormValues({
    required this.nome,
    required this.formato,
    required this.partitePerStagione,
    required this.useGettoni,
    required this.gettoniPerGiocatore,
    required this.quotaIscrizione,
    required this.quotaTesseramento,
    required this.costoPartita,
  });
}

/// Form di creazione squadra: formato in cima, perche' decide i default di tutto il resto.
class _TeamFormDialog extends StatefulWidget {
  final String title;
  final List<TeamFormatInfo> formats;
  final Future<bool> Function(TeamFormValues) onSubmit;
  final String? Function() errorOf;

  const _TeamFormDialog({
    required this.title,
    required this.formats,
    required this.onSubmit,
    required this.errorOf,
  });

  @override
  State<_TeamFormDialog> createState() => _TeamFormDialogState();
}

class _TeamFormDialogState extends State<_TeamFormDialog> {
  final _nome = TextEditingController();
  final _partite = TextEditingController(text: '8');
  final _gettoni = TextEditingController(text: '4');
  final _iscrizione = TextEditingController(text: '0');
  final _tesseramento = TextEditingController(text: '0');
  final _costoPartita = TextEditingController(text: '0');

  TeamFormat _formato = TeamFormat.calcioA5;
  bool _useGettoni = true;
  bool _busy = false;

  @override
  void dispose() {
    _nome.dispose();
    _partite.dispose();
    _gettoni.dispose();
    _iscrizione.dispose();
    _tesseramento.dispose();
    _costoPartita.dispose();
    super.dispose();
  }

  TeamFormatInfo get _info => widget.formats.firstWhere(
        (f) => f.formato == _formato,
        orElse: () => TeamFormatInfo.local(_formato),
      );

  Future<void> _submit() async {
    if (_nome.text.trim().isEmpty) return;
    setState(() => _busy = true);

    final ok = await widget.onSubmit(TeamFormValues(
      nome: _nome.text.trim(),
      formato: _formato,
      partitePerStagione: int.tryParse(_partite.text) ?? 8,
      useGettoni: _useGettoni,
      gettoniPerGiocatore: _useGettoni ? (int.tryParse(_gettoni.text) ?? 4) : 0,
      quotaIscrizione: double.tryParse(_iscrizione.text.replaceAll(',', '.')) ?? 0,
      quotaTesseramento: double.tryParse(_tesseramento.text.replaceAll(',', '.')) ?? 0,
      costoPartita: double.tryParse(_costoPartita.text.replaceAll(',', '.')) ?? 0,
    ));

    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.errorOf() ?? 'Errore nella creazione')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome squadra'),
            ),
            const SizedBox(height: 16),
            const Eyebrow('FORMATO'),
            const SizedBox(height: 8),
            AppChoiceChips<TeamFormat>(
              values: TeamFormat.values,
              selected: _formato,
              label: (f) => f.shortLabel,
              onChanged: (f) => setState(() => _formato = f!),
            ),
            const SizedBox(height: 6),
            Text(
              '${_info.label}: ${_info.giocatoriInCampo} in campo, max ${_info.maxConvocati} convocati, '
              '${_info.numeroTempi}x${_info.minutiPerTempo} minuti.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _partite,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Partite per stagione'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usa i gettoni'),
              value: _useGettoni,
              onChanged: (v) => setState(() => _useGettoni = v),
            ),
            if (_useGettoni)
              TextField(
                controller: _gettoni,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gettoni per giocatore'),
              ),
            const SizedBox(height: 16),
            const Eyebrow('COSTI (EUR)'),
            const SizedBox(height: 6),
            TextField(
              controller: _iscrizione,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quota iscrizione'),
            ),
            TextField(
              controller: _tesseramento,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quota tesseramento'),
            ),
            TextField(
              controller: _costoPartita,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Costo a partita'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crea'),
        ),
      ],
    );
  }
}

class MemberFormValues {
  final String nome;
  final String? soprannome;
  final String? telefono;
  final String? note;
  final String? email;
  final String? password;

  MemberFormValues({
    required this.nome,
    this.soprannome,
    this.telefono,
    this.note,
    this.email,
    this.password,
  });
}

class _MemberFormDialog extends StatefulWidget {
  final ClubMember? member;
  final Future<bool> Function(MemberFormValues) onSubmit;
  final String? Function() errorOf;

  const _MemberFormDialog({
    required this.member,
    required this.onSubmit,
    required this.errorOf,
  });

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _soprannome;
  late final TextEditingController _telefono;
  late final TextEditingController _note;
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nome = TextEditingController(text: m?.nome ?? '');
    _soprannome = TextEditingController(text: m?.soprannome ?? '');
    _telefono = TextEditingController(text: m?.telefono ?? '');
    _note = TextEditingController(text: m?.note ?? '');
    _email = TextEditingController(text: m?.email ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _soprannome.dispose();
    _telefono.dispose();
    _note.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _haGiaAccount => widget.member?.haAccount ?? false;

  Future<void> _submit() async {
    if (_nome.text.trim().isEmpty) return;
    setState(() => _busy = true);

    final ok = await widget.onSubmit(MemberFormValues(
      nome: _nome.text.trim(),
      soprannome: _soprannome.text.trim(),
      telefono: _telefono.text.trim(),
      note: _note.text.trim(),
      email: _haGiaAccount ? null : _email.text.trim(),
      password: _haGiaAccount ? null : _password.text,
    ));

    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.errorOf() ?? 'Errore nel salvataggio')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.member == null ? 'Nuova persona' : widget.member!.nome),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I dati anagrafici valgono in tutte le squadre della società.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nome,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _soprannome,
              decoration: const InputDecoration(labelText: 'Soprannome'),
            ),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
            ),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: 16),
            if (_haGiaAccount)
              Text(
                'Account: ${widget.member!.email}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              )
            else ...[
              Text(
                'Account (serve per iscriverla a una squadra)',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password iniziale',
                  helperText: 'Minimo 6 caratteri, solo se l\'account non esiste',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
      ],
    );
  }
}

/// Iscrizione a una squadra: qui si scelgono ruolo in campo e numero, che
/// valgono solo per quella squadra (lo stesso giocatore puo' essere pivot a 5 e ala a 7).
class _EnrollSheet extends StatefulWidget {
  final ClubMember member;
  final List<ClubTeam> squadre;
  final List<PlayerPosition> Function(TeamFormat) positionsFor;
  final Future<bool> Function(int teamId, String ruolo, PlayerPosition? posizione, int? numero)
      onSubmit;
  final String? Function() errorOf;

  const _EnrollSheet({
    required this.member,
    required this.squadre,
    required this.positionsFor,
    required this.onSubmit,
    required this.errorOf,
  });

  @override
  State<_EnrollSheet> createState() => _EnrollSheetState();
}

class _EnrollSheetState extends State<_EnrollSheet> {
  late int _teamId;
  PlayerPosition? _posizione;
  final _numero = TextEditingController();
  Ruolo _ruolo = Ruolo.giocatore;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _teamId = widget.squadre.first.id;
  }

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  ClubTeam get _squadra => widget.squadre.firstWhere((t) => t.id == _teamId);

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await widget.onSubmit(
      _teamId,
      _ruolo.apiValue,
      _posizione,
      int.tryParse(_numero.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.errorOf() ?? 'Errore')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final posizioni = widget.positionsFor(_squadra.formato);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHandle(),
            DisplayText('ISCRIVI ${widget.member.displayName.toUpperCase()}', size: 26),
            const SizedBox(height: 4),
            Text(
              'Gettoni, quote e statistiche partono da zero per la nuova squadra.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Eyebrow('SQUADRA'),
            const SizedBox(height: 8),
            AppChoiceChips<int>(
              values: widget.squadre.map((t) => t.id).toList(),
              selected: _teamId,
              label: (id) {
                final t = widget.squadre.firstWhere((t) => t.id == id);
                return '${t.nome} (${t.formato.shortLabel})';
              },
              onChanged: (id) => setState(() {
                _teamId = id!;
                // I ruoli dipendono dal formato: quello scelto prima puo' non valere piu'
                _posizione = null;
              }),
            ),
            const SizedBox(height: 16),
            Eyebrow('RUOLO IN ${_squadra.formatoLabel.toUpperCase()}'),
            const SizedBox(height: 8),
            AppChoiceChips<PlayerPosition?>(
              values: [null, ...posizioni],
              selected: _posizione,
              label: (p) => p?.label ?? 'Nessuno',
              onChanged: (p) => setState(() => _posizione = p),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numero,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Numero di maglia (opzionale)'),
            ),
            const SizedBox(height: 12),
            const Eyebrow('RUOLO NELLA SQUADRA'),
            const SizedBox(height: 8),
            AppChoiceChips<Ruolo>(
              values: Ruolo.values,
              selected: _ruolo,
              label: (r) => r.label,
              onChanged: (r) => setState(() => _ruolo = r!),
            ),
            const SizedBox(height: 4),
            Text(_ruolo.descrizione,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Iscrivi a ${_squadra.nome}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
