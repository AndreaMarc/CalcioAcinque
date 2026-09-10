import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/theme_provider.dart';
import '../models/announcement_model.dart';
import '../widgets/app_widgets.dart';

class BachecaScreen extends StatefulWidget {
  const BachecaScreen({super.key});

  @override
  State<BachecaScreen> createState() => _BachecaScreenState();
}

class _BachecaScreenState extends State<BachecaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId > 0) {
      context.read<AnnouncementsProvider>().loadAnnouncements(auth.teamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);

    return Consumer<AnnouncementsProvider>(
      builder: (context, prov, _) {
        return Column(
          children: [
            AppTopBar(
              teamInitials: initials,
              title: 'Bacheca',
              subtitle: '${prov.announcements.length} aggiornamenti',
              actions: [
                if (auth.puoGestireCampo)
                  AppTopBar.iconAction(
                    context,
                    Icons.add,
                    () => _showCreateDialog(context),
                  ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: !prov.hasLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : prov.announcements.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 200),
                              Center(child: Text('Bacheca vuota')),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            children: prov.announcements
                                .map((a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _BoardCard(
                                        ann: a,
                                        isAdmin: auth.puoGestireCampo,
                                        onAcknowledge: () => _acknowledge(a),
                                        onDelete: () => _confirmDelete(a),
                                        onTap: () => _showDetail(a),
                                      ),
                                    ))
                                .toList(),
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acknowledge(AnnouncementModel ann) async {
    final auth = context.read<AuthProvider>();
    final success = await context.read<AnnouncementsProvider>()
        .acknowledge(auth.teamId, ann.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presa visione registrata')),
      );
    }
  }

  Future<void> _confirmDelete(AnnouncementModel ann) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina comunicazione'),
        content: Text('Eliminare "${ann.titolo}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTokens.bad),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final auth = context.read<AuthProvider>();
      await context.read<AnnouncementsProvider>().delete(auth.teamId, ann.id);
    }
  }

  Future<void> _showDetail(AnnouncementModel ann) async {
    final auth = context.read<AuthProvider>();
    final detail = await context.read<AnnouncementsProvider>()
        .getDetail(auth.teamId, ann.id);
    if (detail == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? AppTokens.darkText : AppTokens.text;
          final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muteColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (detail.importante)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: AppChip(
                    text: 'IMPORTANTE',
                    variant: AppChipVariant.brand,
                  ),
                ),
              Text(
                detail.titolo.toUpperCase(),
                style: GoogleFonts.bebasNeue(
                  fontSize: 28,
                  height: 1.1,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${detail.autoreDisplay} · ${DateFormat('d MMM y HH:mm', 'it_IT').format(detail.createdAt)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: muteColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                detail.contenuto,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  color: textColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (!detail.hoPresaVisione)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _acknowledge(ann);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Presa Visione'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titoloCtrl = TextEditingController();
    final contenutoCtrl = TextEditingController();
    bool importante = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuova Comunicazione'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titoloCtrl,
                  decoration: const InputDecoration(labelText: 'Titolo'),
                  maxLength: 200,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contenutoCtrl,
                  decoration: const InputDecoration(labelText: 'Contenuto'),
                  maxLines: 5,
                  maxLength: 2000,
                ),
                SwitchListTile(
                  title: const Text('Importante'),
                  value: importante,
                  onChanged: (v) => setDialogState(() => importante = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                if (titoloCtrl.text.trim().isEmpty ||
                    contenutoCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                await context.read<AnnouncementsProvider>().create(
                      auth.teamId,
                      titolo: titoloCtrl.text.trim(),
                      contenuto: contenutoCtrl.text.trim(),
                      importante: importante,
                    );
              },
              child: const Text('Pubblica'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final AnnouncementModel ann;
  final bool isAdmin;
  final VoidCallback onAcknowledge;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BoardCard({
    required this.ann,
    required this.isAdmin,
    required this.onAcknowledge,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final line2Color = isDark ? AppTokens.darkLine : AppTokens.line2;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final faintColor = isDark
        ? AppTokens.darkTextMute.withOpacity(0.5)
        : AppTokens.textFaint;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ann.importante ? AppTokens.brand : lineColor,
            width: ann.importante ? 1.5 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (ann.importante)
              Positioned(
                top: -1,
                right: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    color: AppTokens.brand,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin, size: 10, color: AppTokens.brandInk),
                      const SizedBox(width: 4),
                      Text(
                        'FISSATO',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.brandInk,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ann.importante) const SizedBox(height: 10),
                Row(
                  children: [
                    AppChip(
                      text: ann.importante ? 'IMPORTANTE' : 'AVVISO',
                      variant: ann.importante
                          ? AppChipVariant.brand
                          : AppChipVariant.dark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      fontSize: 9,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ann.autoreDisplay} · ${_timeAgo(ann.createdAt)}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: faintColor,
                      ),
                    ),
                    const Spacer(),
                    if (!ann.hoPresaVisione)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTokens.brand,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ann.titolo.toUpperCase(),
                  style: GoogleFonts.bebasNeue(
                    fontSize: 22,
                    height: 1.1,
                    letterSpacing: 0.01 * 22,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ann.contenuto,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: muteColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: line2Color, style: BorderStyle.solid),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppChip(
                        text:
                            '${ann.totalePresaVisione}/${ann.totaleGiocatori} letti',
                        variant: AppChipVariant.neutral,
                        leadingIcon: Icons.visibility_outlined,
                        fontSize: 11,
                      ),
                      const SizedBox(width: 8),
                      if (!ann.hoPresaVisione)
                        InkWell(
                          onTap: onAcknowledge,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTokens.brand.withOpacity(0.15)
                                  : AppTokens.brandSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    size: 13,
                                    color: isDark
                                        ? AppTokens.darkBrand
                                        : AppTokens.brandInk),
                                const SizedBox(width: 4),
                                Text(
                                  'Letto',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTokens.darkBrand
                                        : AppTokens.brandInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (isAdmin)
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: AppTokens.bad.withOpacity(0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours}h fa';
    if (diff.inDays < 7) return '${diff.inDays}g fa';
    return DateFormat('dd/MM').format(dt);
  }
}
