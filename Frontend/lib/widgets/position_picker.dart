import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_draft.dart' show PlayerPosition, PlayerPositionX;
import '../models/team_format.dart';
import '../providers/club_provider.dart';

/// Ruolo in campo tra quelli del formato della squadra (a5, a7...).
class PositionPicker extends StatelessWidget {
  final TeamFormat formato;
  final PlayerPosition? selected;
  final ValueChanged<PlayerPosition?> onChanged;

  const PositionPicker({
    super.key,
    required this.formato,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final posizioni = context.read<ClubProvider>().positionsFor(formato);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ruolo (${formato.label})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Nessuno'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            ...posizioni.map((p) => ChoiceChip(
                  label: Text(p.label),
                  selected: selected == p,
                  onSelected: (_) => onChanged(p),
                )),
          ],
        ),
      ],
    );
  }
}
