import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_mark.dart';
import '../widgets/join_team_dialog.dart';
import '../widgets/team_utils.dart';

/// Arrivo da un link di invito (`/#/join/CODICE`): apre subito il dialog di
/// adesione con il codice gia' compilato e verificato. Senza login il router
/// manda prima al login e poi torna qui.
class JoinScreen extends StatefulWidget {
  final String code;
  const JoinScreen({super.key, required this.code});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (_opened || !mounted) return;
    _opened = true;
    var joined = false;
    await showJoinTeamDialog(
      context,
      initialCode: widget.code,
      onJoined: () {
        joined = true;
        resetTeamProviders(context);
        context.go('/dashboard');
      },
    );
    if (!mounted || joined) return;
    // Dialog chiuso senza aderire: si torna dove ha senso
    final auth = context.read<AuthProvider>();
    context.go(auth.needsTeamSelection ? '/select-team' : '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.ink,
      body: Stack(
        children: [
          const GlowSpot(top: -180, left: -140),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandWordmark(markSize: 28),
                  const SizedBox(height: 36),
                  const Eyebrow('INVITO', color: AppTokens.brand),
                  const SizedBox(height: 10),
                  const DisplayText('ENTRA IN\nSQUADRA', size: 44, color: Colors.white, height: 0.95),
                  const SizedBox(height: 12),
                  Text(
                    'Codice ${widget.code.toUpperCase()}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppTokens.textOnInkMute),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
