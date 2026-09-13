import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../models/chore_model.dart';
import '../models/convocation_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Turni della partita (casacche, palloni, maglie): a chi tocca, con
/// rotazione automatica tra i convocati e correzione a mano dallo staff.
/// Non compare se la squadra non ha turni configurati.
class TurniCard extends StatefulWidget {
  final int matchId;
  final bool canEdit;
  final List<ConvocationModel> convocati;

  /// Quando cambia (pull-to-refresh del padre) la card si ricarica.
  final int refreshTick;
  const TurniCard({
    super.key,
    required this.matchId,
    required this.canEdit,
    required this.convocati,
    this.refreshTick = 0,
  });

  @override
  State<TurniCard> createState() => _TurniCardState();
}

class _TurniCardState extends State<TurniCard> {
  List<MatchChoreModel>? _turni;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TurniCard old) {
    super.didUpdateWidget(old);
    if (old.refreshTick != widget.refreshTick || old.matchId != widget.matchId) _load();
  }

  Future<void> _load() async {
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      final resp = await dio.get(ApiConstants.matchChores(widget.matchId));
      if (!mounted) return;
      setState(() => _turni = (resp.data['data'] as List)
          .map((e) => MatchChoreModel.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      if (mounted) setState(() => _turni = const []);
    }
  }

  Future<void> _assegna() async {
    setState(() => _busy = true);
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      final resp = await dio.post(ApiConstants.matchChoresAssign(widget.matchId));
      if (!mounted) return;
      setState(() => _turni = (resp.data['data'] as List)
          .map((e) => MatchChoreModel.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messaggio(e) ?? 'Non riesco ad assegnare i turni')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _imposta(MatchChoreModel turno, int? playerId) async {
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      final resp = await dio.put(
        ApiConstants.matchChore(widget.matchId, turno.choreId),
        data: {'playerId': playerId},
      );
      if (!mounted) return;
      setState(() => _turni = (resp.data['data'] as List)
          .map((e) => MatchChoreModel.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messaggio(e) ?? 'Non riesco a cambiare il turno')),
      );
    }
  }

  void _scegli(MatchChoreModel turno) {
    final candidati = widget.convocati.where((c) => !c.isNonDisponibile).toList()
      ..sort((a, b) => (a.soprannome ?? a.nomeGiocatore).compareTo(b.soprannome ?? b.nomeGiocatore));
    showAppSheet<void>(
      context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppTokens.darkText : AppTokens.text;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DisplayText(turno.nome.toUpperCase(), size: 22, color: textColor),
                const SizedBox(height: 6),
                if (candidati.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nessun convocato: prima manda le convocazioni.'),
                  ),
                ...candidati.map((c) => AppSheetAction(
                      icon: Icons.person_outline,
                      label: c.soprannome ?? c.nomeGiocatore,
                      subtitle: c.isConfermato ? 'ha confermato' : 'in attesa di risposta',
                      selected: turno.playerId == c.playerId,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _imposta(turno, c.playerId);
                      },
                    )),
                if (turno.assegnato)
                  AppSheetAction(
                    icon: Icons.remove_circle_outline,
                    label: 'Libera il turno',
                    destructive: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _imposta(turno, null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String? _messaggio(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] != null) return data['message'] as String;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final turni = _turni;
    if (turni == null || turni.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final daAssegnare = turni.any((t) => !t.assegnato);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('TURNI DI SQUADRA')),
                if (widget.canEdit && daAssegnare)
                  TextButton.icon(
                    onPressed: _busy ? null : _assegna,
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.shuffle, size: 16),
                    label: const Text('Assegna'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...turni.map((t) => InkWell(
                  onTap: widget.canEdit ? () => _scegli(t) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          t.assegnato ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                          size: 18,
                          color: t.assegnato ? (isDark ? AppTokens.darkBrand : AppTokens.brand) : muteColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.nome,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            t.assegnato ? t.chi : 'da assegnare',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              color: t.assegnato ? textColor : muteColor,
                              fontStyle: t.assegnato ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ),
                        if (widget.canEdit) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 18, color: muteColor),
                        ],
                      ],
                    ),
                  ),
                )),
            if (!widget.canEdit && daAssegnare)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'I turni li assegna il mister dopo le convocazioni.',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
