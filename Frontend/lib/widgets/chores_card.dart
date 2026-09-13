import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../models/chore_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Configurazione dei turni di squadra (Impostazioni, solo admin).
class ChoresCard extends StatefulWidget {
  final int teamId;
  const ChoresCard({super.key, required this.teamId});

  @override
  State<ChoresCard> createState() => _ChoresCardState();
}

class _ChoresCardState extends State<ChoresCard> {
  List<TeamChoreModel>? _chores;
  final _nuovoCtrl = TextEditingController();
  bool _busy = false;

  static const _suggerimenti = ['Casacche', 'Palloni', 'Maglie da lavare', 'Acqua'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nuovoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      final resp = await dio.get(ApiConstants.teamChores(widget.teamId));
      if (mounted) {
        setState(() => _chores = (resp.data['data'] as List)
            .map((e) => TeamChoreModel.fromJson(e as Map<String, dynamic>))
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _chores = const []);
    }
  }

  Future<void> _aggiungi(String nome) async {
    final n = nome.trim();
    if (n.isEmpty) return;
    setState(() => _busy = true);
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      await dio.post(ApiConstants.teamChores(widget.teamId), data: {'nome': n});
      _nuovoCtrl.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non riesco ad aggiungere il turno')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(TeamChoreModel c, bool attivo) async {
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      await dio.put(ApiConstants.chore(c.id), data: {'nome': c.nome, 'attivo': attivo});
      await _load();
    } catch (_) {}
  }

  Future<void> _elimina(TeamChoreModel c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminare "${c.nome}"?',
      message: 'Sparisce anche dallo storico dei turni fatti.',
      confirmLabel: 'Elimina',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      await dio.delete(ApiConstants.chore(c.id));
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final chores = _chores;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compiti che girano a turno tra i convocati: l\'app sceglie chi non lo fa da più tempo, '
            'il mister può correggere partita per partita.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor, height: 1.35),
          ),
          const SizedBox(height: 12),
          if (chores == null)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (chores.isEmpty) ...[
            Text('Nessun turno. Idee:', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggerimenti
                  .map((s) => ActionChip(
                        label: Text(s),
                        onPressed: _busy ? null : () => _aggiungi(s),
                      ))
                  .toList(),
            ),
          ] else
            ...chores.map((c) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.nome,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.attivo ? textColor : muteColor,
                              decoration: c.attivo ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        Switch(value: c.attivo, onChanged: (v) => _toggle(c, v)),
                        IconButton(
                          tooltip: 'Elimina',
                          icon: Icon(Icons.delete_outline, color: muteColor, size: 20),
                          onPressed: () => _elimina(c),
                        ),
                      ],
                    ),
                    if (c != chores.last) Divider(color: lineColor, height: 1),
                  ],
                )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuovoCtrl,
                  decoration: const InputDecoration(hintText: 'Nuovo turno, es. Casacche', isDense: true),
                  onSubmitted: _aggiungi,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy ? null : () => _aggiungi(_nuovoCtrl.text),
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
