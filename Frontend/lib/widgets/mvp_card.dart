import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../models/mvp_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Il migliore in campo: chi e' in testa e il proprio voto (uno, tra i presenti).
class MvpCard extends StatefulWidget {
  final int matchId;
  const MvpCard({super.key, required this.matchId});

  @override
  State<MvpCard> createState() => _MvpCardState();
}

class _MvpCardState extends State<MvpCard> {
  MatchMvp? _mvp;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      final resp = await dio.get(ApiConstants.matchMvp(widget.matchId));
      if (mounted) setState(() => _mvp = MatchMvp.fromJson(resp.data['data'] as Map<String, dynamic>));
    } catch (_) {}
  }

  Future<void> _vota(int? playerId) async {
    setState(() => _busy = true);
    try {
      final dio = context.read<AuthProvider>().apiClient.dio;
      final resp = playerId == null
          ? await dio.delete(ApiConstants.matchMvp(widget.matchId))
          : await dio.post(ApiConstants.matchMvp(widget.matchId), data: {'playerId': playerId});
      if (mounted) setState(() => _mvp = MatchMvp.fromJson(resp.data['data'] as Map<String, dynamic>));
    } catch (e) {
      if (!mounted) return;
      String msg = 'Non riesco a registrare il voto';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['message'] != null) msg = data['message'] as String;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mvp = _mvp;
    if (mvp == null || !mvp.aperto) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final me = context.read<AuthProvider>().currentPlayer?.id;
    final votabili = mvp.candidati.where((c) => c.playerId != me).toList();
    final leader = mvp.leader;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('MIGLIORE IN CAMPO')),
                AppChip(
                  text: mvp.totaleVoti == 1 ? '1 voto' : '${mvp.totaleVoti} voti',
                  variant: mvp.totaleVoti > 0 ? AppChipVariant.brand : AppChipVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (leader.isEmpty)
              Text(
                'Nessun voto ancora: vota tu per primo.',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muteColor),
              )
            else
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppTokens.warn, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leader.map((l) => l.displayName).join(' e '),
                          style: GoogleFonts.bebasNeue(fontSize: 26, height: 1, color: textColor),
                        ),
                        Text(
                          '${leader.first.voti} ${leader.first.voti == 1 ? 'voto' : 'voti'}'
                          '${leader.length > 1 ? ' a testa' : ''}'
                          '${mvp.classifica.length > leader.length ? ' · poi ${mvp.classifica.skip(leader.length).take(2).map((c) => '${c.displayName} ${c.voti}').join(', ')}' : ''}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Text(
              mvp.mioVotoPlayerId == null ? 'IL TUO VOTO' : 'HAI VOTATO · tocca di nuovo per togliere',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: muteColor,
              ),
            ),
            const SizedBox(height: 8),
            if (votabili.isEmpty)
              Text(
                'Nessun presente da votare.',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
              )
            else
              Opacity(
                opacity: _busy ? 0.6 : 1,
                child: AppChoiceChips<int>(
                  values: votabili.map((c) => c.playerId).toList(),
                  selected: mvp.mioVotoPlayerId,
                  allowNull: true,
                  label: (id) => votabili.firstWhere((c) => c.playerId == id).displayName,
                  onChanged: _busy ? (_) {} : _vota,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
