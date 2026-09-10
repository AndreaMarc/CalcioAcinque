import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/season_model.dart';
import '../providers/club_provider.dart';

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

  return showModalBottomSheet<SeasonChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final corrente = _aperta(seasons);

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Stagione',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(corrente != null ? 'In corso (${corrente.nome})' : 'In corso'),
              subtitle: const Text('Segue sempre la stagione aperta'),
              trailing: selected == null ? Icon(Icons.check, color: cs.primary) : null,
              onTap: () => Navigator.of(ctx).pop(const SeasonChoice(null)),
            ),
            const Divider(height: 1),
            ...seasons.map((s) => ListTile(
                  leading: Icon(s.chiusa ? Icons.inventory_2_outlined : Icons.circle_outlined),
                  title: Text(s.nome),
                  subtitle: Text(
                    '${s.partite} partite'
                    '${s.chiusa ? ' · archiviata' : ' · aperta'}',
                  ),
                  trailing: selected == s.id ? Icon(Icons.check, color: cs.primary) : null,
                  onTap: () => Navigator.of(ctx).pop(SeasonChoice(s.id)),
                )),
          ],
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.secondaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label - archivio, solo consultazione',
              style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
            ),
          ),
          TextButton(onPressed: onTorna, child: const Text('Torna a oggi')),
        ],
      ),
    );
  }
}
