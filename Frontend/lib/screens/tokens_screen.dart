import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../core/constants/api_constants.dart';
import '../models/dashboard_model.dart';
import '../widgets/app_widgets.dart';

class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key});

  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends State<TokensScreen> {
  List<PlayerTokenSummary> _summaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.apiClient.dio
          .get(ApiConstants.teamTokens(auth.teamId));
      if (response.data['success'] == true) {
        setState(() {
          _summaries = (response.data['data'] as List)
              .map((e) => PlayerTokenSummary.fromJson(e))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final useGettoni = context.watch<DashboardProvider>().useGettoni;
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);

    if (!useGettoni) {
      return Column(
        children: [
          AppTopBar(
            teamInitials: initials,
            title: 'Gettoni',
            subtitle: 'Sistema disabilitato',
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.toll, size: 48, color: AppTokens.textMute),
                  const SizedBox(height: 12),
                  Text('Sistema gettoni disabilitato',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Column(
        children: [
          AppTopBar(
            teamInitials: initials,
            title: 'Gettoni',
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    final sorted = List<PlayerTokenSummary>.from(_summaries)
      ..sort((a, b) => b.gettoniRimanenti.compareTo(a.gettoniRimanenti));

    final mySummary = _summaries
        .where((s) => s.playerId == auth.playerId)
        .cast<PlayerTokenSummary?>()
        .firstOrNull;
    final myTokens = mySummary?.gettoniRimanenti ?? 0;
    final myTotal = mySummary?.gettoniTotali ?? 0;

    return Column(
      children: [
        AppTopBar(
          teamInitials: initials,
          title: 'Gettoni',
          subtitle: 'Classifica squadra',
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTokens,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _TokensHero(
                    tokens: myTokens,
                    total: myTotal,
                  ),
                ),
                SectionHead(
                  title: 'CLASSIFICA TEAM',
                  more: 'Chi resta più a lungo',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: sorted.asMap().entries.map((e) {
                      final idx = e.key;
                      final p = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _RankRow(
                          rank: idx + 1,
                          player: p,
                          isMe: p.playerId == auth.playerId,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TokensHero extends StatelessWidget {
  final int tokens;
  final int total;
  const _TokensHero({required this.tokens, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = total > 0 ? '$tokens' : '0';
    return CardInk(
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTokens.brand.withOpacity(0.2),
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTokens.brand.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I TUOI GETTONI',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.54,
                  color: AppTokens.brand,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    remaining,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 96,
                      height: 0.85,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/ $total',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tokens > 0
                    ? 'Ti restano $tokens ${tokens == 1 ? "partita" : "partite"} prima della ricarica'
                    : 'Gettoni esauriti — ricarica disponibile',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 14),
              if (total > 0) ...[
                GettoniBar(filled: tokens, total: total, cellHeight: 6),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final PlayerTokenSummary player;
  final bool isMe;
  const _RankRow({
    required this.rank,
    required this.player,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    final bg = isMe
        ? (isDark ? AppTokens.brand.withOpacity(0.12) : AppTokens.brandSoft)
        : cardColor;
    final border =
        isMe ? AppTokens.brand : lineColor;
    final warn = player.gettoniRimanenti <= 2 && player.gettoniRimanenti > 0;
    final out = player.gettoniRimanenti == 0;
    final valueColor = out
        ? AppTokens.bad
        : warn
            ? AppTokens.warn
            : textColor;

    return Opacity(
      opacity: out ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: isMe ? 1.5 : 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: muteColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            JerseyNumber(
              number: rank,
              size: 40,
              fontSize: 19,
              bg: AppTokens.ink,
              fg: out
                  ? AppTokens.bad
                  : (isDark ? AppTokens.darkBrand : AppTokens.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${player.soprannome?.isNotEmpty == true ? player.soprannome : player.nome}${isMe ? " (tu)" : ""}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  GettoniBar(
                    filled: player.gettoniRimanenti,
                    total: player.gettoniTotali.clamp(1, 999),
                    cellHeight: 4,
                    filledColor: out
                        ? AppTokens.bad
                        : warn
                            ? AppTokens.warn
                            : (isDark ? Colors.white : AppTokens.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${player.gettoniRimanenti}',
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
