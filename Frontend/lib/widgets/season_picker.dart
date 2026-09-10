import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/season_model.dart';
import '../providers/club_provider.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Sceglie la stagione da guardare. Ritorna l'id scelto, `null` per la stagione
/// in corso, e non ritorna nulla se si chiude senza scegliere: per distinguere
/// i due casi si usa [SeasonChoice].
Future<SeasonChoice?> showSeasonPicker(
  BuildContext context, {
  required int teamId,
  int? selected,
}) async {
  final club = context.read<ClubProvider>();
  if (club.seasons.isEmpty) await club.loadSeasons(teamId);
  if (!context.mounted) return null;

  final seasons = club.seasons;
  if (seasons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nessuna stagione disponibile')),
    );
    return null;
  }

  return showAppSheet<SeasonChoice>(
    context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textColor = isDark ? AppTokens.darkText : AppTokens.text;
      final corrente = _aperta(seasons);

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DisplayText('STAGIONE', size: 22, color: textColor),
              const SizedBox(height: 6),
              AppSheetAction(
                icon: Icons.play_circle_outline,
                label: corrente != null ? 'In corso (${corrente.nome})' : 'In corso',
                subtitle: 'Segue sempre la stagione aperta',
                selected: selected == null,
                onTap: () => Navigator.of(ctx).pop(const SeasonChoice(null)),
              ),
              const Divider(height: 16),
              ...seasons.map((s) => AppSheetAction(
                    icon: s.chiusa ? Icons.inventory_2_outlined : Icons.circle_outlined,
                    label: s.nome,
                    subtitle: '${s.partite} partite${s.chiusa ? ' · archiviata' : ' · aperta'}',
                    selected: selected == s.id,
                    onTap: () => Navigator.of(ctx).pop(SeasonChoice(s.id)),
                  )),
            ],
          ),
        ),
      );
    },
  );
}

/// Involucro per poter restituire `null` come scelta valida.
class SeasonChoice {
  final int? seasonId;
  const SeasonChoice(this.seasonId);
}

/// Etichetta da mostrare nella barra: il nome della stagione scelta, oppure
/// quello della stagione aperta quando non si e' filtrato.
String seasonLabel(List<SeasonModel> seasons, int? seasonId) {
  if (seasons.isEmpty) return 'Stagione in corso';
  if (seasonId == null) {
    final corrente = _aperta(seasons);
    return corrente != null ? 'Stagione ${corrente.nome}' : 'Stagione in corso';
  }
  for (final s in seasons) {
    if (s.id == seasonId) return 'Stagione ${s.nome}';
  }
  return 'Stagione';
}

SeasonModel? _aperta(List<SeasonModel> seasons) {
  for (final s in seasons) {
    if (!s.chiusa) return s;
  }
  return null;
}

/// Fascia che ricorda che si sta guardando una stagione chiusa: senza di essa
/// una lista di partite vecchie sembra la lista di partite di adesso.
class SeasonArchiveBanner extends StatelessWidget {
  final String label;
  final VoidCallback onTorna;

  const SeasonArchiveBanner({super.key, required this.label, required this.onTorna});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTokens.ink,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 16, color: AppTokens.textOnInkMute),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label - archivio, solo consultazione',
              style: const TextStyle(fontSize: 12, color: AppTokens.textOnInk),
            ),
          ),
          TextButton(
            onPressed: onTorna,
            style: TextButton.styleFrom(foregroundColor: AppTokens.brand),
            child: const Text('Torna a oggi'),
          ),
        ],
      ),
    );
  }
}
