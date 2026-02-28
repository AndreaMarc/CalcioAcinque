import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/announcements_provider.dart';
import '../models/announcement_model.dart';

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<AnnouncementsProvider>(
          builder: (context, prov, _) {
            if (!prov.hasLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (prov.announcements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined, size: 64,
                      color: cs.onSurfaceVariant.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text('Nessuna comunicazione',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text('La bacheca e\' vuota',
                      style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 13)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prov.announcements.length,
              itemBuilder: (context, index) {
                final ann = prov.announcements[index];
                return _AnnouncementCard(
                  announcement: ann,
                  isAdmin: auth.isAdmin,
                  onAcknowledge: () => _acknowledge(ann),
                  onDelete: () => _confirmDelete(ann),
                  onTap: () => _showDetail(ann),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
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
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final auth = context.read<AuthProvider>();
      final success = await context.read<AnnouncementsProvider>()
          .delete(auth.teamId, ann.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comunicazione eliminata')),
        );
      }
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
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) {
          final cs = Theme.of(ctx).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (detail.importante)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.priority_high, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text('IMPORTANTE', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: Colors.red.shade700)),
                      ],
                    ),
                  ),
                Text(detail.titolo,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(detail.autoreDisplay,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(detail.createdAt),
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
                const Divider(height: 24),
                Text(detail.contenuto,
                  style: Theme.of(ctx).textTheme.bodyLarge),
                const SizedBox(height: 24),
                // Presa visione section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          Text('Presa visione',
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Chip(
                            label: Text(
                              '${detail.totalePresaVisione} / ${detail.totaleGiocatori}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            backgroundColor: cs.primaryContainer,
                          ),
                        ],
                      ),
                      if (detail.presaVisione.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...detail.presaVisione.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 18,
                                color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              Expanded(child: Text(r.displayName,
                                style: const TextStyle(fontSize: 14))),
                              Text(
                                DateFormat('dd/MM HH:mm').format(r.readAt),
                                style: TextStyle(fontSize: 12,
                                  color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )),
                      ],
                      if (detail.presaVisione.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Nessuno ha ancora preso visione',
                          style: TextStyle(fontStyle: FontStyle.italic,
                            color: cs.onSurfaceVariant, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                if (!detail.hoPresaVisione) ...[
                  const SizedBox(height: 16),
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
              ],
            ),
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
                  decoration: const InputDecoration(
                    labelText: 'Titolo',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contenutoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contenuto',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  maxLength: 2000,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Importante'),
                  subtitle: const Text('Evidenzia la comunicazione'),
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
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                if (titoloCtrl.text.trim().isEmpty ||
                    contenutoCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final success = await context.read<AnnouncementsProvider>().create(
                  auth.teamId,
                  titolo: titoloCtrl.text.trim(),
                  contenuto: contenutoCtrl.text.trim(),
                  importante: importante,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comunicazione pubblicata')),
                  );
                }
              },
              child: const Text('Pubblica'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isAdmin;
  final VoidCallback onAcknowledge;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.isAdmin,
    required this.onAcknowledge,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ann = announcement;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ann.importante)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.red.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text('IMPORTANTE', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.red.shade700, letterSpacing: 0.5)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(ann.titolo,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold)),
                      ),
                      if (!ann.hoPresaVisione)
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ann.contenuto.length > 120
                        ? '${ann.contenuto.substring(0, 120)}...'
                        : ann.contenuto,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14,
                        color: cs.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(ann.autoreDisplay,
                        style: TextStyle(fontSize: 12,
                          color: cs.onSurfaceVariant.withOpacity(0.6))),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14,
                        color: cs.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(_timeAgo(ann.createdAt),
                        style: TextStyle(fontSize: 12,
                          color: cs.onSurfaceVariant.withOpacity(0.6))),
                      const Spacer(),
                      Icon(Icons.visibility, size: 14,
                        color: cs.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text('${ann.totalePresaVisione}/${ann.totaleGiocatori}',
                        style: TextStyle(fontSize: 12,
                          color: cs.onSurfaceVariant.withOpacity(0.6))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!ann.hoPresaVisione)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onAcknowledge,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Presa Visione'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.check_circle,
                              size: 18, color: Colors.green.shade600),
                            label: Text('Visualizzato',
                              style: TextStyle(color: Colors.green.shade600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.green.shade300),
                            ),
                          ),
                        ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade400, size: 22),
                          tooltip: 'Elimina',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    if (diff.inDays < 7) return '${diff.inDays} giorni fa';
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}
