import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/team_draft.dart';
import '../models/team_format.dart';
import '../providers/auth_provider.dart';
import '../providers/team_draft_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/gimmy_widgets.dart';

class DraftScreen extends StatefulWidget {
  final int? initialDraftId;
  const DraftScreen({super.key, this.initialDraftId});

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> with WidgetsBindingObserver {
  DraftStatus? _filter;
  bool _initialized = false;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await context.read<TeamDraftProvider>().loadDrafts(preferredId: widget.initialDraftId);
        _startPolling();
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      context.read<TeamDraftProvider>().refreshSilently();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sospende il polling quando la tab/app non è in primo piano
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<TeamDraftProvider>().refreshSilently();
        _startPolling();
      }
    } else {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _switchDraft(int id) {
    context.read<TeamDraftProvider>().selectDraft(id);
    context.go('/draft?id=$id');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeamDraftProvider>();
    final draft = provider.currentDraft;
    final loading = provider.isLoading && !provider.hasLoaded;

    return Scaffold(
      backgroundColor: GimmyTokens.ink,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: GimmyTokens.brand))
            : Column(
                children: [
                  _Header(
                    onBack: () => context.go('/select-team'),
                    drafts: provider.drafts,
                    currentDraft: draft,
                    onSwitchDraft: _switchDraft,
                    onShare: draft == null ? null : () => _showShareSheet(draft),
                  ),
                  Expanded(
                    child: draft == null
                        ? _EmptyDraft(onCreate: () => _showSetupDialog())
                        : _DraftBody(
                            draft: draft,
                            filter: _filter,
                            onFilterChange: (s) => setState(() => _filter = s),
                            onEditSetup: () => _showSetupDialog(existing: draft),
                            onAddCandidate: () => _showCandidateEditor(draft.id, null),
                            onEditCandidate: (c) => _showCandidateEditor(draft.id, c),
                            onRemoveCandidate: (c) => _confirmRemoveCandidate(draft.id, c),
                            onAddFriends: (c) => _showAddFriendsDialog(draft.id, c),
                            onRefresh: () => context
                                .read<TeamDraftProvider>()
                                .loadDrafts(preferredId: draft.id),
                          ),
                  ),
                  if (draft != null)
                    _LaunchBar(draft: draft, onLaunch: _confirmLaunch),
                ],
              ),
      ),
    );
  }

  Future<void> _showSetupDialog({TeamDraft? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.nomeTeam ?? '');
    final partiteCtrl = TextEditingController(text: '${existing?.partitePerStagione ?? 8}');
    final gettoniCtrl = TextEditingController(text: '${existing?.gettoniPerGiocatore ?? 4}');
    var useGettoni = existing?.useGettoni ?? true;
    var formato = existing?.formato ?? TeamFormat.calcioA5;
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Crea il draft' : 'Modifica draft'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome team'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Formato',
                        style: Theme.of(ctx).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: TeamFormat.values
                        .map((f) => ChoiceChip(
                              label: Text(f.shortLabel),
                              selected: formato == f,
                              onSelected: (_) => setLocal(() => formato = f),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${formato.label}: ${formato.giocatoriInCampo} in campo. '
                      'Decide i ruoli proponibili sui candidati.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: partiteCtrl,
                    decoration: const InputDecoration(labelText: 'Partite per stagione'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 50) return 'Tra 1 e 50';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: gettoniCtrl,
                    decoration: const InputDecoration(labelText: 'Gettoni per giocatore'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 0 || n > 100) return 'Tra 0 e 100';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: useGettoni,
                    onChanged: (v) => setLocal(() => useGettoni = v),
                    title: const Text('Usa sistema gettoni'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final provider = context.read<TeamDraftProvider>();
                final ok = existing == null
                    ? (await provider.createDraft(
                          nomeTeam: nameCtrl.text.trim(),
                          formato: formato,
                          partitePerStagione: int.tryParse(partiteCtrl.text) ?? 8,
                          gettoniPerGiocatore: int.tryParse(gettoniCtrl.text) ?? 4,
                          useGettoni: useGettoni,
                        )) !=
                        null
                    : await provider.updateDraft(
                        draftId: existing.id,
                        nomeTeam: nameCtrl.text.trim(),
                        formato: formato,
                        partitePerStagione: int.tryParse(partiteCtrl.text) ?? 8,
                        gettoniPerGiocatore: int.tryParse(gettoniCtrl.text) ?? 4,
                        useGettoni: useGettoni,
                      );
                if (!mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.error ?? 'Errore')),
                  );
                }
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCandidateEditor(int draftId, DraftCandidate? existing) async {
    final draft = context.read<TeamDraftProvider>().currentDraft;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GimmyTokens.ink2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CandidateEditor(
        draftId: draftId,
        existing: existing,
        formato: draft?.formato ?? TeamFormat.calcioA5,
      ),
    );
  }

  Future<void> _confirmRemoveCandidate(int draftId, DraftCandidate c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovere candidato?'),
        content: Text('${c.nome}${c.soprannome != null ? ' "${c.soprannome}"' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rimuovi')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<TeamDraftProvider>().removeCandidate(draftId, c.id);
    }
  }

  Future<void> _showAddFriendsDialog(int draftId, DraftCandidate parent) async {
    int selected = 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Amici di ${parent.nome}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crea N segnaposto chiamati "${parent.nome} 1", "${parent.nome} 2", ecc. '
                  'Ereditano la posizione di ${parent.nome}, stato "Da sentire", '
                  'bravura/affidabilità basse. Li potrai editare dopo.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: List.generate(6, (i) {
                    final n = i + 1;
                    final isSel = n == selected;
                    return ChoiceChip(
                      label: Text('$n'),
                      selected: isSel,
                      onSelected: (_) => setLocal(() => selected = n),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.group_add, size: 16),
              label: Text('Aggiungi $selected'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final provider = context.read<TeamDraftProvider>();
    final success = await provider.addFriends(draftId, parent.id, selected);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Errore')),
      );
    }
  }

  Future<void> _showShareSheet(TeamDraft draft) async {
    final base = Uri.base.origin;
    final link = '$base/#/draft/join/${draft.shareCode}';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GimmyTokens.ink2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Invita collaboratori',
                style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Condividi il link: chi lo apre può vedere e modificare la rosa, ma solo te puoi lanciare la squadra.',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        link,
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copiato'), duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.copy, color: GimmyTokens.brand),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CODICE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                draft.shareCode,
                style: GoogleFonts.firaCode(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GimmyTokens.brand,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'COLLABORATORI · ${draft.collaborators.length}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              ...draft.collaborators.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c.isOwner
                              ? GimmyTokens.brand.withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          c.isOwner ? Icons.star_rounded : Icons.person_outline,
                          size: 16,
                          color: c.isOwner ? GimmyTokens.brand : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.email,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.isOwner)
                        Text(
                          'Owner',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: GimmyTokens.brand,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLaunch(TeamDraft draft) async {
    if (!draft.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo l\'owner del draft può lanciare la squadra')),
      );
      return;
    }

    final confermati = draft.countByStatus(DraftStatus.confermato);
    if (confermati == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serve almeno 1 candidato Confermato')),
      );
      return;
    }

    final nomeCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lanciare la squadra?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${draft.nomeTeam}" verrà creato con $confermati '
                  '${confermati == 1 ? 'giocatore' : 'giocatori'} confermati.'),
              const SizedBox(height: 16),
              const Text('Come ti chiami nel team?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome (obbligatorio)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: soprannomeCtrl,
                decoration: const InputDecoration(labelText: 'Soprannome (opzionale)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              if (nomeCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Lancia'),
          ),
        ],
      ),
    );

    if (go != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.launchTeamFromDraft(
      draftId: draft.id,
      nomeGiocatore: nomeCtrl.text.trim(),
      soprannome: soprannomeCtrl.text.trim().isEmpty ? null : soprannomeCtrl.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      context.read<TeamDraftProvider>().reset();
      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Errore nel lancio')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final List<TeamDraft> drafts;
  final TeamDraft? currentDraft;
  final ValueChanged<int> onSwitchDraft;
  final VoidCallback? onShare;

  const _Header({
    required this.onBack,
    required this.drafts,
    required this.currentDraft,
    required this.onSwitchDraft,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CONFIGURATORE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: GimmyTokens.brand,
                  ),
                ),
                if (drafts.length <= 1)
                  Text(
                    currentDraft?.nomeTeam.toUpperCase() ?? 'Pianifica la squadra',
                    style: GoogleFonts.bebasNeue(fontSize: 26, color: Colors.white, height: 1.05),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  _DraftSwitcher(
                    drafts: drafts,
                    currentDraft: currentDraft,
                    onSwitch: onSwitchDraft,
                  ),
              ],
            ),
          ),
          if (onShare != null)
            InkWell(
              onTap: onShare,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 36,
                decoration: BoxDecoration(
                  color: GimmyTokens.brand.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share, color: GimmyTokens.brand, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _DraftSwitcher extends StatelessWidget {
  final List<TeamDraft> drafts;
  final TeamDraft? currentDraft;
  final ValueChanged<int> onSwitch;
  const _DraftSwitcher({required this.drafts, required this.currentDraft, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onSwitch,
      color: GimmyTokens.ink2,
      offset: const Offset(0, 36),
      itemBuilder: (ctx) => drafts
          .map((d) => PopupMenuItem<int>(
                value: d.id,
                child: Row(
                  children: [
                    if (d.isOwner)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.star_rounded, size: 14, color: GimmyTokens.brand),
                      ),
                    Text(d.nomeTeam,
                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              currentDraft?.nomeTeam.toUpperCase() ?? 'Scegli draft',
              style: GoogleFonts.bebasNeue(fontSize: 26, color: Colors.white, height: 1.05),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.6), size: 22),
        ],
      ),
    );
  }
}

class _EmptyDraft extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyDraft({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: GimmyTokens.brand.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.groups, color: GimmyTokens.brand, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              'Inizia il draft',
              style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Costruisci la lista di candidati con stato, '
              'bravura e affidabilità. Lanci la squadra quando hai i numeri giusti.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: GimmyTokens.brand,
                foregroundColor: GimmyTokens.brandInk,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Crea draft'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftBody extends StatelessWidget {
  final TeamDraft draft;
  final DraftStatus? filter;
  final ValueChanged<DraftStatus?> onFilterChange;
  final VoidCallback onEditSetup;
  final VoidCallback onAddCandidate;
  final ValueChanged<DraftCandidate> onEditCandidate;
  final ValueChanged<DraftCandidate> onRemoveCandidate;
  final ValueChanged<DraftCandidate> onAddFriends;
  final Future<void> Function() onRefresh;

  const _DraftBody({
    required this.draft,
    required this.filter,
    required this.onFilterChange,
    required this.onEditSetup,
    required this.onAddCandidate,
    required this.onEditCandidate,
    required this.onRemoveCandidate,
    required this.onAddFriends,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filter == null
        ? draft.candidates
        : draft.candidates.where((c) => c.stato == filter).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: GimmyTokens.brand,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _SetupCard(draft: draft, onEdit: onEditSetup),
        const SizedBox(height: 16),
        _SummaryRow(
          draft: draft,
          activeFilter: filter,
          onFilterTap: onFilterChange,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CANDIDATI',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.white.withOpacity(0.55),
              ),
            ),
            TextButton.icon(
              onPressed: onAddCandidate,
              icon: const Icon(Icons.add, color: GimmyTokens.brand),
              label: Text(
                'Aggiungi',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GimmyTokens.brand,
                ),
              ),
            ),
          ],
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                filter == null ? 'Nessun candidato' : 'Nessun candidato in questo stato',
                style: GoogleFonts.spaceGrotesk(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          )
        else
          ...filtered.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CandidateTile(
                  candidate: c,
                  onTap: () => onEditCandidate(c),
                  onRemove: () => onRemoveCandidate(c),
                  onAddFriends: c.isFriend ? null : () => onAddFriends(c),
                ),
              )),
      ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final TeamDraft draft;
  final VoidCallback onEdit;
  const _SetupCard({required this.draft, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: GimmyTokens.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                teamInitials(draft.nomeTeam, fallback: '?'),
                style: GoogleFonts.bebasNeue(fontSize: 22, color: GimmyTokens.brandInk),
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
                      if (!draft.isOwner) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.people, size: 14, color: Colors.white.withOpacity(0.5)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${draft.formato.shortLabel} • ${draft.partitePerStagione} partite • '
                    '${draft.useGettoni ? "${draft.gettoniPerGiocatore} gettoni" : "no gettoni"} • '
                    '${draft.collaborators.length} ${draft.collaborators.length == 1 ? "membro" : "membri"}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final TeamDraft draft;
  final DraftStatus? activeFilter;
  final ValueChanged<DraftStatus?> onFilterTap;

  const _SummaryRow({
    required this.draft,
    required this.activeFilter,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _summaryChip(null, 'Tutti', draft.candidates.length, Colors.white),
          const SizedBox(width: 8),
          for (final s in DraftStatus.values) ...[
            _summaryChip(s, s.label, draft.countByStatus(s), _colorFor(s)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(DraftStatus? s, String label, int count, Color color) {
    final selected = activeFilter == s;
    return InkWell(
      onTap: () => onFilterTap(s),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$label · $count',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorFor(DraftStatus s) {
  switch (s) {
    case DraftStatus.confermato:
      return GimmyTokens.ok;
    case DraftStatus.inForse:
      return GimmyTokens.warn;
    case DraftStatus.daSentire:
      return GimmyTokens.info;
    case DraftStatus.rifiutato:
      return GimmyTokens.bad;
  }
}

GimmyChipVariant _chipVariantFor(DraftStatus s) {
  switch (s) {
    case DraftStatus.confermato:
      return GimmyChipVariant.ok;
    case DraftStatus.inForse:
      return GimmyChipVariant.warn;
    case DraftStatus.daSentire:
      return GimmyChipVariant.brand;
    case DraftStatus.rifiutato:
      return GimmyChipVariant.bad;
  }
}

const Color _kFriendColor = Color(0xFF9D6BFF);

class _CandidateTile extends StatelessWidget {
  final DraftCandidate candidate;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onAddFriends;

  const _CandidateTile({
    required this.candidate,
    required this.onTap,
    required this.onRemove,
    required this.onAddFriends,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final accent = c.isFriend ? _kFriendColor : _colorFor(c.stato);
    final bg = c.isFriend
        ? _kFriendColor.withOpacity(0.06)
        : Colors.white.withOpacity(0.04);
    final border = c.isFriend
        ? _kFriendColor.withOpacity(0.3)
        : Colors.white.withOpacity(0.08);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: c.isFriend
                      ? Icon(Icons.person_outline, size: 22, color: accent)
                      : Text(
                          teamInitials(c.nome, fallback: '?'),
                          style: GoogleFonts.bebasNeue(fontSize: 18, color: accent),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.soprannome != null && c.soprannome!.isNotEmpty
                            ? '${c.nome} "${c.soprannome}"'
                            : c.nome,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (c.isFriend)
                        Text(
                          'Amico (da identificare)',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: _kFriendColor.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (c.posizione != null)
                        Text(
                          c.posizione!.label,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                GimmyChip(text: c.stato.label, variant: _chipVariantFor(c.stato)),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline,
                      color: Colors.white.withOpacity(0.4), size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StarRow(label: 'Bravura', value: c.bravura),
                const SizedBox(width: 16),
                _StarRow(label: 'Affidabilità', value: c.affidabilita),
                const Spacer(),
                if (c.tesserato)
                  GimmyChip(
                    text: 'Tesserato',
                    leadingIcon: Icons.verified,
                    variant: GimmyChipVariant.brand,
                  ),
                if (onAddFriends != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onAddFriends,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kFriendColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _kFriendColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_add, size: 13, color: _kFriendColor),
                          const SizedBox(width: 6),
                          Text(
                            '+ amici',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kFriendColor,
                              letterSpacing: 0.02,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (c.note != null && c.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                c.note!,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.55),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final String label;
  final int value;
  const _StarRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: List.generate(
            5,
            (i) => Icon(
              i < value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 14,
              color: i < value ? GimmyTokens.brand : Colors.white.withOpacity(0.25),
            ),
          ),
        ),
      ],
    );
  }
}

class _LaunchBar extends StatelessWidget {
  final TeamDraft draft;
  final ValueChanged<TeamDraft> onLaunch;
  const _LaunchBar({required this.draft, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final confermati = draft.countByStatus(DraftStatus.confermato);
    final canLaunch = draft.isOwner && confermati > 0 && draft.nomeTeam.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: InkWell(
        onTap: canLaunch ? () => onLaunch(draft) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: canLaunch ? GimmyTokens.brand : GimmyTokens.brand.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                draft.isOwner
                    ? 'Lancia squadra · $confermati'
                    : 'Solo l\'owner può lanciare',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GimmyTokens.brandInk,
                ),
              ),
              if (draft.isOwner) ...[
                const SizedBox(width: 8),
                const Icon(Icons.rocket_launch, color: GimmyTokens.brandInk, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateEditor extends StatefulWidget {
  final int draftId;
  final DraftCandidate? existing;
  /// Formato del draft: filtra i ruoli proponibili (un pivot non esiste a 7).
  final TeamFormat formato;
  const _CandidateEditor({
    required this.draftId,
    this.existing,
    required this.formato,
  });

  @override
  State<_CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<_CandidateEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _soprannomeCtrl;
  late TextEditingController _noteCtrl;
  PlayerPosition? _posizione;
  late DraftStatus _stato;
  late int _bravura;
  late int _affidabilita;
  late bool _tesserato;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.nome ?? '');
    _soprannomeCtrl = TextEditingController(text: e?.soprannome ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _posizione = e?.posizione;
    _stato = e?.stato ?? DraftStatus.daSentire;
    _bravura = e?.bravura ?? 3;
    _affidabilita = e?.affidabilita ?? 3;
    _tesserato = e?.tesserato ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _soprannomeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final provider = context.read<TeamDraftProvider>();
    final ok = widget.existing == null
        ? await provider.addCandidate(
            widget.draftId,
            nome: _nameCtrl.text.trim(),
            soprannome: _soprannomeCtrl.text.trim().isEmpty ? null : _soprannomeCtrl.text.trim(),
            posizione: _posizione,
            stato: _stato,
            bravura: _bravura,
            affidabilita: _affidabilita,
            tesserato: _tesserato,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          )
        : await provider.updateCandidate(
            widget.draftId,
            widget.existing!.id,
            nome: _nameCtrl.text.trim(),
            soprannome: _soprannomeCtrl.text.trim().isEmpty ? null : _soprannomeCtrl.text.trim(),
            posizione: _posizione,
            stato: _stato,
            bravura: _bravura,
            affidabilita: _affidabilita,
            tesserato: _tesserato,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Errore')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Nuovo candidato' : 'Modifica candidato',
                style: GoogleFonts.bebasNeue(fontSize: 26, color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _soprannomeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Soprannome'),
              ),
              const SizedBox(height: 18),
              Text('Posizione (${widget.formato.label})', style: _labelStyle()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _selectChip('Nessuna', _posizione == null, () => setState(() => _posizione = null)),
                  for (final p in widget.formato.posizioni)
                    _selectChip(p.label, _posizione == p, () => setState(() => _posizione = p)),
                ],
              ),
              const SizedBox(height: 18),
              Text('Stato', style: _labelStyle()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in DraftStatus.values)
                    _selectChip(
                      s.label,
                      _stato == s,
                      () => setState(() => _stato = s),
                      tint: _colorFor(s),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _StarPicker(
                label: 'Bravura',
                value: _bravura,
                onChanged: (v) => setState(() => _bravura = v),
              ),
              const SizedBox(height: 12),
              _StarPicker(
                label: 'Affidabilità',
                value: _affidabilita,
                onChanged: (v) => setState(() => _affidabilita = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _tesserato,
                activeColor: GimmyTokens.brand,
                onChanged: (v) => setState(() => _tesserato = v),
                title: Text('Tesserato', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Annulla', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: GimmyTokens.brand,
                        foregroundColor: GimmyTokens.brandInk,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GimmyTokens.brandInk,
                              ),
                            )
                          : const Text('Salva'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.white.withOpacity(0.6),
      );

  Widget _selectChip(String label, bool selected, VoidCallback onTap, {Color? tint}) {
    final color = tint ?? GimmyTokens.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _StarPicker({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
          ),
        ),
        Row(
          children: List.generate(5, (i) {
            final idx = i + 1;
            return InkWell(
              onTap: () => onChanged(idx),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  idx <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 28,
                  color: idx <= value ? GimmyTokens.brand : Colors.white.withOpacity(0.3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
