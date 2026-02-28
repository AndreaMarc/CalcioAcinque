import 'dart:typed_data';
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/constants/api_constants.dart';
import '../providers/matches_provider.dart';
import '../providers/players_provider.dart';
import '../providers/announcements_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final theme = context.read<ThemeProvider>();
    _nameCtrl = TextEditingController(text: theme.teamName);
    // Load teams if not loaded
    final auth = context.read<AuthProvider>();
    if (auth.teams == null) {
      auth.loadMyTeams();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final completer = Completer<Uint8List?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/*';
    input.click();
    input.addEventListener('change', (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);
      reader.addEventListener('loadend', (web.Event e) {
        final arrayBuffer = reader.result as JSArrayBuffer;
        final bytes = arrayBuffer.toDart.asUint8List();
        completer.complete(bytes);
      }.toJS);
    }.toJS);

    final bytes = await completer.future;
    if (bytes != null && mounted) {
      await context.read<ThemeProvider>().setLogo(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo caricato!')));
      }
    }
  }

  void _resetAllProviders() {
    context.read<DashboardProvider>().reset();
    context.read<MatchesProvider>().reset();
    context.read<PlayersProvider>().reset();
    context.read<AnnouncementsProvider>().reset();
  }

  Future<void> _switchToTeam(int teamId) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.switchTeam(teamId);
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

  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final player = auth.currentPlayer;
    if (player == null) return;

    final nomeCtrl = TextEditingController(text: player.nome);
    final soprannomeCtrl = TextEditingController(text: player.soprannome ?? '');
    final telefonoCtrl = TextEditingController(text: player.telefono ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Modifica Profilo'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                final success = await auth.updateMyProfile(
                  nome: nomeCtrl.text.trim(),
                  soprannome: soprannomeCtrl.text.trim(),
                  telefono: telefonoCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success
                        ? 'Profilo aggiornato!'
                        : 'Errore nell\'aggiornamento del profilo')),
                  );
                }
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleUseGettoni(bool value) async {
    final auth = context.read<AuthProvider>();
    try {
      final response = await auth.apiClient.dio.put(
        ApiConstants.team(auth.teamId),
        data: {'useGettoni': value},
      );
      if (response.data['success'] == true && mounted) {
        context.read<DashboardProvider>().loadDashboard(auth.teamId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value
              ? 'Sistema gettoni attivato'
              : 'Sistema gettoni disattivato')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'aggiornamento')),
        );
      }
    }
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

  Future<void> _showInviteCode() async {
    final auth = context.read<AuthProvider>();
    final code = await auth.getInviteCode();
    if (!mounted) return;

    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Codice Invito'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Condividi questo codice con i giocatori che vuoi invitare nel tuo team:',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        code ?? 'Non disponibile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: cs.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (code != null)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copia',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Codice copiato!')),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final teams = auth.teams ?? [];
    final currentTeamId = auth.teamId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profilo
          _buildSectionHeader(context, 'Profilo', Icons.person_outline),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          (auth.currentPlayer?.nome ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold,
                            color: cs.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.currentPlayer?.nome ?? 'Utente',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold),
                            ),
                            if (auth.currentPlayer?.soprannome != null &&
                                auth.currentPlayer!.soprannome!.isNotEmpty)
                              Text(
                                '"${auth.currentPlayer!.soprannome!}"',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13,
                                  fontStyle: FontStyle.italic),
                              ),
                            Text(
                              auth.isAdmin ? 'Amministratore' : 'Giocatore',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                            ),
                            if (auth.currentPlayer?.telefono != null &&
                                auth.currentPlayer!.telefono!.isNotEmpty)
                              Text(
                                auth.currentPlayer!.telefono!,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      if (auth.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Admin',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: cs.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: _showEditProfileDialog,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Modifica Profilo'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // I miei Team
          _buildSectionHeader(context, 'I miei Team', Icons.groups_outlined),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (teams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nessun team caricato'),
                  )
                else
                  ...teams.asMap().entries.map((entry) {
                    final index = entry.key;
                    final team = entry.value;
                    final isActive = team.teamId == currentTeamId;
                    return Column(
                      children: [
                        if (index > 0)
                          Divider(height: 1, indent: 16, endIndent: 16,
                            color: cs.outlineVariant.withOpacity(0.3)),
                        ListTile(
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  team.teamName,
                                  style: TextStyle(
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: team.isAdmin
                                      ? cs.primaryContainer
                                      : cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  team.isAdmin ? 'Admin' : 'Giocatore',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: team.isAdmin ? cs.primary : cs.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: isActive
                              ? Text('Team attivo', style: TextStyle(
                                  fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500))
                              : null,
                          trailing: isActive
                              ? Icon(Icons.check_circle, color: cs.primary, size: 22)
                              : FilledButton.tonal(
                                  onPressed: () => _switchToTeam(team.teamId),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(0, 34),
                                  ),
                                  child: const Text('Cambia', style: TextStyle(fontSize: 12)),
                                ),
                        ),
                      ],
                    );
                  }),
                Divider(height: 1, indent: 16, endIndent: 16,
                  color: cs.outlineVariant.withOpacity(0.3)),
                // Admin invite code
                if (auth.isAdmin)
                  ListTile(
                    leading: Icon(Icons.vpn_key_outlined, color: cs.primary),
                    title: const Text('Codice invito'),
                    subtitle: Text('Invita giocatori al tuo team',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showInviteCode,
                  ),
                if (auth.isAdmin)
                  Divider(height: 1, indent: 16, endIndent: 16,
                    color: cs.outlineVariant.withOpacity(0.3)),
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: cs.primary),
                  title: const Text('Crea nuovo team'),
                  onTap: _showCreateTeamDialog,
                ),
                Divider(height: 1, indent: 16, endIndent: 16,
                  color: cs.outlineVariant.withOpacity(0.3)),
                ListTile(
                  leading: Icon(Icons.link, color: cs.primary),
                  title: const Text('Unisciti a un team'),
                  onTap: _showJoinTeamDialog,
                ),
              ],
            ),
          ),

          // Configurazione Team (solo admin)
          if (auth.isAdmin) ...[
            const SizedBox(height: 28),
            _buildSectionHeader(context, 'Configurazione Team', Icons.tune_outlined),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(Icons.toll, color: cs.primary),
                    title: const Text('Sistema gettoni'),
                    subtitle: Text(
                      context.watch<DashboardProvider>().useGettoni
                          ? 'Attivo - gestione presenze con gettoni'
                          : 'Disattivato',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    value: context.watch<DashboardProvider>().useGettoni,
                    onChanged: (val) => _toggleUseGettoni(val),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Personalizzazione
          _buildSectionHeader(context, 'Personalizzazione', Icons.palette_outlined),
          const SizedBox(height: 8),

          // Logo squadra
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logo squadra',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Anteprima logo
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                        ),
                        child: theme.hasLogo && theme.logoBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.memory(
                                theme.logoBytes!,
                                fit: BoxFit.cover,
                                width: 72, height: 72,
                              ),
                            )
                          : Icon(Icons.sports_soccer, size: 36,
                              color: cs.onSurfaceVariant.withOpacity(0.4)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton.tonal(
                              onPressed: _pickLogo,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.upload, size: 18),
                                  const SizedBox(width: 8),
                                  Text(theme.hasLogo ? 'Cambia logo' : 'Carica logo'),
                                ],
                              ),
                            ),
                            if (theme.hasLogo) ...[
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () async {
                                  await theme.removeLogo();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Logo rimosso')));
                                  }
                                },
                                child: Text('Rimuovi',
                                  style: TextStyle(fontSize: 12, color: cs.error)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Formati supportati: PNG, JPG. Dimensione consigliata: 200x200 px.',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Nome squadra
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nome squadra',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            hintText: 'Es. I Campioni',
                            fillColor: cs.surfaceContainerLow,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          if (_nameCtrl.text.trim().isNotEmpty) {
                            theme.setTeamName(_nameCtrl.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nome aggiornato!')));
                          }
                        },
                        child: const Text('Salva'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Colore primario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Colore principale',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ThemeProvider.availableColors.map((color) {
                      final isSelected = theme.primaryColor.value == color.value;
                      return GestureDetector(
                        onTap: () => theme.setPrimaryColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(
                              color: cs.onSurface, width: 3) : null,
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8, spreadRadius: 1),
                            ] : null,
                          ),
                          child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Colore accento
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Colore accento',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ThemeProvider.availableAccentColors.map((color) {
                      final isSelected = theme.accentColor.value == color.value;
                      return GestureDetector(
                        onTap: () => theme.setAccentColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(
                              color: cs.onSurface, width: 3) : null,
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8, spreadRadius: 1),
                            ] : null,
                          ),
                          child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Anteprima
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Anteprima',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        // Logo o icona
                        if (theme.hasLogo && theme.logoBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              theme.logoBytes!,
                              width: 56, height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Icon(Icons.sports_soccer, size: 40, color: cs.primary),
                        const SizedBox(height: 8),
                        Text(theme.teamName,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: cs.primary)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton(
                              onPressed: () {},
                              child: const Text('Primario'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonal(
                              onPressed: () {},
                              child: const Text('Secondario'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Azioni
          _buildSectionHeader(context, 'Account', Icons.manage_accounts_outlined),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                  title: const Text('Versione'),
                  trailing: Text('1.0.0', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                Divider(height: 1, indent: 16, endIndent: 16,
                  color: cs.outlineVariant.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Esci', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final auth = context.read<AuthProvider>();
                    await auth.logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: cs.primary, letterSpacing: 0.5)),
      ],
    );
  }
}
