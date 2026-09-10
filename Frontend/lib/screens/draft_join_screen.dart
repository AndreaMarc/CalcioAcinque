import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/team_draft_provider.dart';
import '../providers/theme_provider.dart';

class DraftJoinScreen extends StatefulWidget {
  final String code;
  const DraftJoinScreen({super.key, required this.code});

  @override
  State<DraftJoinScreen> createState() => _DraftJoinScreenState();
}

class _DraftJoinScreenState extends State<DraftJoinScreen> {
  bool _busy = true;
  String? _error;
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<TeamDraftProvider>();

    // Mostra prima un preview pubblico
    final preview = await provider.previewByShareCode(widget.code);
    if (mounted) setState(() => _preview = preview);

    if (preview == null) {
      if (mounted) setState(() {
        _busy = false;
        _error = 'Codice non valido o draft scaduto';
      });
      return;
    }

    if (!auth.isAuthenticated) {
      // Non autenticato → vai al login mantenendo il next
      if (mounted) {
        context.go('/login?next=${Uri.encodeQueryComponent('/draft/join/${widget.code}')}');
      }
      return;
    }

    // Autenticato → join
    final joined = await provider.joinByShareCode(widget.code);
    if (!mounted) return;
    if (joined == null) {
      setState(() {
        _busy = false;
        _error = provider.error ?? 'Impossibile entrare nel draft';
      });
      return;
    }
    context.go('/draft?id=${joined.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GimmyTokens.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DRAFT INVITE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: GimmyTokens.brand,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _preview?['nomeTeam'] ?? 'Caricamento...',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 44,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Owner: ${_preview!['ownerEmail']}  ·  '
                      'Candidati: ${_preview!['candidatesCount']}  ·  '
                      'Collaboratori: ${_preview!['collaboratorsCount']}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_busy)
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: GimmyTokens.brand,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Entro nel draft…', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: GimmyTokens.bad.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GimmyTokens.bad.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: GimmyTokens.bad, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.spaceGrotesk(
                                color: GimmyTokens.bad,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Torna al login',
                          style: TextStyle(color: GimmyTokens.brand)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
