import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Dialog "Unisciti con codice", unico per scelta squadra e impostazioni.
///
/// Un codice puo' essere di una squadra o di una società': nel secondo caso
/// con piu' squadre si sceglie a quale unirsi (il server lo esige, altrimenti
/// risponde 400). Se chi gestisce la rosa aveva gia' inserito il giocatore, il
/// suo nome compare sotto "Sei uno di questi?" e riprende la scheda esistente.
///
/// [onJoined] viene chiamato dopo l'adesione riuscita, con il context della
/// schermata chiamante ancora montato.
Future<void> showJoinTeamDialog(
  BuildContext context, {
  required VoidCallback onJoined,
  /// Codice gia' noto (link o QR di invito): compilato e verificato subito.
  String? initialCode,
}) {
  final codeCtrl = TextEditingController(text: initialCode?.trim().toUpperCase() ?? '');
  var autoVerifica = (initialCode ?? '').trim().isNotEmpty;
  final nomeCtrl = TextEditingController();
  final soprannomeCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> squadre = const [];
  List<Map<String, dynamic>> pending = const [];
  String? nomeSocieta;
  String? nomeSquadra;
  int? teamId;
  int? selectedPendingId;
  var verificando = false;
  var verificato = false;
  var codiceValido = false;
  var invio = false;

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final cs = Theme.of(ctx).colorScheme;

        Future<void> verifica() async {
          final code = codeCtrl.text.trim();
          if (code.isEmpty) return;
          setDialogState(() => verificando = true);

          final info = await context.read<AuthProvider>().getJoinInfo(code);
          if (!ctx.mounted) return;

          setDialogState(() {
            verificando = false;
            verificato = true;
            codiceValido = info != null;
            nomeSocieta = info?['clubName'] as String?;
            nomeSquadra = info?['teamName'] as String?;
            squadre = ((info?['teams'] as List?) ?? const [])
                .cast<Map<String, dynamic>>()
                .toList();
            pending = ((info?['pendingPlayers'] as List?) ?? const [])
                .cast<Map<String, dynamic>>()
                .toList();
            teamId = squadre.length == 1 ? squadre.first['teamId'] as int? : null;
            selectedPendingId = null;
          });
        }

        Future<void> unisciti() async {
          if (!formKey.currentState!.validate()) return;
          if (!codiceValido) {
            await verifica();
            if (!ctx.mounted || !codiceValido) return;
          }
          if (squadre.length > 1 && teamId == null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Scegli a quale squadra unirti')),
            );
            return;
          }
          setDialogState(() => invio = true);
          final auth = context.read<AuthProvider>();
          final success = await auth.joinTeam(
            inviteCode: codeCtrl.text.trim(),
            nome: nomeCtrl.text.trim(),
            soprannome: soprannomeCtrl.text.trim(),
            telefono: telefonoCtrl.text.trim(),
            pendingPlayerId: selectedPendingId,
            teamId: teamId,
          );
          if (!ctx.mounted) return;
          if (success) {
            Navigator.of(ctx).pop();
            if (context.mounted) {
              context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
              onJoined();
            }
          } else {
            // Il form resta aperto: niente da riscrivere
            setDialogState(() => invio = false);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(auth.error ?? 'Non riesco a unirti alla squadra')),
            );
          }
        }

        if (autoVerifica) {
          autoVerifica = false;
          WidgetsBinding.instance.addPostFrameCallback((_) => verifica());
        }

        return AlertDialog(
          title: const Text('Unisciti con codice'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Codice invito',
                            helperText: 'Di una squadra o della società',
                          ),
                          onChanged: (_) {
                            if (verificato) setDialogState(() => verificato = false);
                          },
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      verificando
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(onPressed: verifica, child: const Text('Verifica')),
                    ],
                  ),
                  if (verificato && !codiceValido) ...[
                    const SizedBox(height: 10),
                    const NoticeBox(
                      variant: AppChipVariant.bad,
                      icon: Icons.error_outline,
                      text: 'Codice non valido. Controlla con chi gestisce la squadra.',
                    ),
                  ],
                  if (codiceValido && squadre.length > 1) ...[
                    const SizedBox(height: 14),
                    Eyebrow(nomeSocieta != null ? 'SQUADRE DI ${nomeSocieta!.toUpperCase()}' : 'SCEGLI LA SQUADRA'),
                    const SizedBox(height: 6),
                    ...squadre.map((t) => RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          value: t['teamId'] as int,
                          groupValue: teamId,
                          title: Text(t['nome'] as String? ?? ''),
                          subtitle: Text(
                            '${t['formatoLabel'] ?? ''} · ${t['totaleGiocatori'] ?? 0} in rosa',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          onChanged: (v) => setDialogState(() => teamId = v),
                        )),
                  ] else if (codiceValido) ...[
                    const SizedBox(height: 10),
                    Text(
                      squadre.length == 1
                          ? 'Ti unisci a ${squadre.first['nome']} (${squadre.first['formatoLabel'] ?? ''})'
                          : 'Ti unisci a ${nomeSquadra ?? 'questa squadra'}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                  if (codiceValido && pending.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Eyebrow('SEI UNO DI QUESTI? (OPZIONALE)'),
                    const SizedBox(height: 8),
                    AppChoiceChips<int>(
                      values: pending.map<int>((p) => p['id'] as int).toList(),
                      selected: selectedPendingId,
                      allowNull: true,
                      spacing: 6,
                      label: (id) => pending.firstWhere((p) => p['id'] == id)['nome'] as String,
                      onChanged: (id) => setDialogState(() {
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
                    validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: soprannomeCtrl,
                    decoration: const InputDecoration(labelText: 'Soprannome'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefono'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: invio ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: invio ? null : unisciti,
              child: invio
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Unisciti'),
            ),
          ],
        );
      },
    ),
  );
}
