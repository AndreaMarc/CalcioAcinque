import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  bool _obscurePassword = true;
  bool _tryingAutoLogin = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _tryAutoLogin();
  }

  String? get _nextParam {
    final uri = GoRouterState.of(context).uri;
    return uri.queryParameters['next'];
  }

  void _navigateAfterAuth(AuthProvider auth) {
    final next = _nextParam;
    // Solo path interni: deve iniziare con '/' e non con '//' (no redirect esterni)
    if (next != null && next.startsWith('/') && !next.startsWith('//')) {
      context.go(next);
      return;
    }
    if (auth.needsTeamSelection) {
      context.go('/select-team');
    } else {
      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
      context.go('/dashboard');
    }
  }

  Future<void> _tryAutoLogin() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.tryAutoLogin();
    if (mounted) {
      setState(() => _tryingAutoLogin = false);
      if (success) {
        _navigateAfterAuth(auth);
      } else {
        _animCtrl.forward();
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) {
      _navigateAfterAuth(auth);
    }
  }

  Future<void> _showSignupDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final passCtrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // ctx, non context: col context esterno il dialog non si ricostruiva
          // mai e l'errore "email gia' registrata" restava invisibile
          final auth = ctx.watch<AuthProvider>();
          return AlertDialog(
            backgroundColor: AppTokens.ink2,
            title: Text(
              'Crea account',
              style: GoogleFonts.bebasNeue(fontSize: 26, color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obbligatorio';
                        if (!v.contains('@')) return 'Email non valida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password (min 6)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                          onPressed: () => setLocal(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Almeno 6 caratteri' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: pass2Ctrl,
                      obscureText: obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Conferma password',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      validator: (v) =>
                          v != passCtrl.text ? 'Le password non coincidono' : null,
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.error!,
                        style: const TextStyle(color: AppTokens.bad, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: auth.isLoading ? null : () => Navigator.pop(ctx, false),
                child: const Text('Annulla', style: TextStyle(color: Colors.white)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.brand,
                  foregroundColor: AppTokens.brandInk,
                ),
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final success = await context.read<AuthProvider>().signup(
                              emailCtrl.text.trim(),
                              passCtrl.text,
                            );
                        if (success && ctx.mounted) Navigator.pop(ctx, true);
                      },
                child: auth.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTokens.brandInk,
                        ),
                      )
                    : const Text('Crea'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && mounted) {
      _navigateAfterAuth(context.read<AuthProvider>());
    }
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.ink2,
        title: Text(
          'Password dimenticata',
          style: GoogleFonts.bebasNeue(fontSize: 26, color: Colors.white),
        ),
        content: Text(
          'Chiedi a chi amministra la tua squadra: dalla Rosa puo\' impostarti una '
          'password nuova in un attimo. Appena entri, cambiala da Impostazioni → Account.',
          style: GoogleFonts.spaceGrotesk(fontSize: 14, height: 1.45, color: AppTokens.textOnInkMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ho capito', style: TextStyle(color: AppTokens.brand)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tryingAutoLogin) {
      return const Scaffold(
        backgroundColor: AppTokens.ink,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 56),
              SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppTokens.brand,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTokens.ink,
      body: Stack(
        children: [
          // Pitch glow top-left
          Positioned(
            top: -180,
            left: -140,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTokens.brand.withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Pitch glow bottom-right
          Positioned(
            bottom: -120,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTokens.brand.withOpacity(0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Wordmark
                            const BrandWordmark(markSize: 36),
                            const SizedBox(height: 60),
                            // Hero copy
                            Text(
                              'CALCIO A 5 · 7 · 8 · 11  ·  STAGIONE ${currentSeasonLabel()}',
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.54,
                                color: AppTokens.brand,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 52,
                                  height: 0.95,
                                  color: Colors.white,
                                  letterSpacing: 0.01 * 52,
                                ),
                                children: const [
                                  TextSpan(text: "CHI C'È\nSTASERA\n"),
                                  TextSpan(
                                    text: 'IN CAMPO?',
                                    style: TextStyle(color: AppTokens.brand),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Gestisci convocazioni, gettoni e presenze della tua squadra. Senza gruppi WhatsApp impazziti.',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                height: 1.5,
                                color: AppTokens.textOnInkMute,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Error
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                if (auth.error == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTokens.bad.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTokens.bad.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: AppTokens.bad,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            auth.error!,
                                            style: GoogleFonts.spaceGrotesk(
                                              color: AppTokens.bad,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            _DarkInput(
                              controller: _emailController,
                              hint: 'Email',
                              icon: Icons.mail_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Inserisci email';
                                }
                                if (!v.contains('@')) return 'Email non valida';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _DarkInput(
                              controller: _passwordController,
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              suffix: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 18,
                                ),
                              ),
                              onSubmit: (_) => _login(),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Inserisci password' : null,
                            ),
                            const SizedBox(height: 20),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return _BrandBtn(
                                  label: 'Entra in campo',
                                  loading: auth.isLoading,
                                  onTap: auth.isLoading ? null : _login,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: _showForgotPassword,
                                child: Text(
                                  'Password dimenticata?',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    color: AppTokens.textOnInkMute,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: InkWell(
                                onTap: _showSignupDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13,
                                        color: AppTokens.textOnInkMute,
                                      ),
                                      children: const [
                                        TextSpan(text: 'Non hai un account? '),
                                        TextSpan(
                                          text: 'Registrati',
                                          style: TextStyle(
                                            color: AppTokens.brand,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmit;
  final String? Function(String?)? validator;

  const _DarkInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onSubmit,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onFieldSubmitted: onSubmit,
        validator: validator,
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 15,
          letterSpacing: obscure ? 0.1 : 0,
        ),
        cursorColor: AppTokens.brand,
        decoration: InputDecoration(
          filled: false,
          isDense: false,
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(
            color: Colors.white.withOpacity(0.35),
            fontSize: 15,
          ),
          prefixIcon: Icon(icon, size: 18, color: Colors.white.withOpacity(0.5)),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: GoogleFonts.spaceGrotesk(
            color: AppTokens.bad,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _BrandBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _BrandBtn({
    required this.label,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppTokens.brand.withOpacity(0.4)
              : AppTokens.brand,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTokens.brandInk,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.brandInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: AppTokens.brandInk,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }
}
