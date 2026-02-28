import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/team_membership_info.dart';

class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  bool _isSelecting = false;

  Future<void> _selectTeam(TeamMembershipInfo team) async {
    if (_isSelecting) return;
    setState(() => _isSelecting = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.selectTeam(team.teamId);
    if (success && mounted) {
      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
      context.go('/dashboard');
    } else if (mounted) {
      setState(() => _isSelecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Errore nella selezione del team')),
      );
    }
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
      builder: (ctx) {
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
                  TextFormField(
                    controller: gettoniCtrl,
                    decoration: const InputDecoration(labelText: 'Gettoni per giocatore'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? 'Numero valido' : null,
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
                final success = await auth.createTeam(
                  nomeTeam: nomeTeamCtrl.text.trim(),
                  nomeGiocatore: nomeGiocatoreCtrl.text.trim(),
                  soprannome: soprannomeCtrl.text.trim(),
                  partitePerStagione: int.parse(partiteCtrl.text),
                  gettoniPerGiocatore: int.parse(gettoniCtrl.text),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (success && mounted) {
                  context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
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
    final cs = Theme.of(context).colorScheme;
    final teams = auth.teams ?? [];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withOpacity(0.08),
              cs.surface,
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.groups, size: 36, color: cs.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seleziona un team',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fai parte di piu\u0300 team. Scegli con quale continuare.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    if (_isSelecting)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      )
                    else
                      ...teams.map((team) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _selectTeam(team),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: cs.primaryContainer,
                                    child: Icon(Icons.sports_soccer, color: cs.primary, size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team.teamName,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          team.isAdmin ? 'Amministratore' : 'Giocatore',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: team.isAdmin
                                          ? cs.primaryContainer
                                          : cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      team.isAdmin ? 'Admin' : 'Giocatore',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: team.isAdmin
                                            ? cs.primary
                                            : cs.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showCreateTeamDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Crea nuovo team'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showJoinTeamDialog,
                            icon: const Icon(Icons.link, size: 18),
                            label: const Text('Unisciti con codice'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
