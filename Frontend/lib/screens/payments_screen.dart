import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/players_provider.dart';
import '../core/constants/api_constants.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<dynamic> _payments = [];
  bool _isLoading = true;
  String _filter = 'tutti'; // tutti, pagati, daPagare

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<PlayersProvider>().loadPlayers(auth.teamId);
      final response = await auth.apiClient.dio
          .get(ApiConstants.teamPayments(auth.teamId));
      if (response.data['success'] == true) {
        setState(() {
          _payments = response.data['data'] as List;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredPayments {
    switch (_filter) {
      case 'pagati':
        return _payments.where((p) => p['pagato'] == true).toList();
      case 'daPagare':
        return _payments.where((p) => p['pagato'] != true).toList();
      default:
        return _payments;
    }
  }

  double get _totaleDovuto =>
      _payments.fold(0.0, (sum, p) => sum + ((p['importo'] as num?)?.toDouble() ?? 0));

  double get _totalePagato => _payments
      .where((p) => p['pagato'] == true)
      .fold(0.0, (sum, p) => sum + ((p['importo'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final filtered = _filteredPayments;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Riepilogo importi
                  _buildSummaryCard(context),
                  const SizedBox(height: 12),
                  // Filtri
                  _buildFilterChips(context),
                  const SizedBox(height: 8),
                  // Lista pagamenti
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.payments_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Nessun pagamento'),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map((p) => _buildPaymentCard(context, p, auth.isAdmin)),
                ],
              ),
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCreatePaymentDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo'),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final mancante = _totaleDovuto - _totalePagato;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem(context, 'Totale', _totaleDovuto, Theme.of(context).colorScheme.primary),
            Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
            _summaryItem(context, 'Pagato', _totalePagato, Colors.green),
            Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
            _summaryItem(context, 'Mancante', mancante, mancante > 0 ? Colors.red : Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(BuildContext context, String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} \u20AC',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final daPagare = _payments.where((p) => p['pagato'] != true).length;
    final pagati = _payments.where((p) => p['pagato'] == true).length;

    return Row(
      children: [
        _chip('Tutti (${_payments.length})', 'tutti'),
        const SizedBox(width: 8),
        _chip('Da pagare ($daPagare)', 'daPagare'),
        const SizedBox(width: 8),
        _chip('Pagati ($pagati)', 'pagati'),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12,
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : null)),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: Theme.of(context).colorScheme.primary,
      showCheckmark: false,
    );
  }

  Widget _buildPaymentCard(BuildContext context, dynamic p, bool isAdmin) {
    final pagato = p['pagato'] == true;
    final importo = (p['importo'] as num?)?.toDouble() ?? 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAdmin ? () => _showEditPaymentDialog(context, p) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icona stato
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: pagato ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  pagato ? Icons.check_circle_rounded : Icons.schedule,
                  color: pagato ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['descrizione'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(p['nomeGiocatore'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall),
                    if (p['note'] != null && (p['note'] as String).isNotEmpty)
                      Text(p['note'], style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              // Importo e data
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${importo.toStringAsFixed(2)} \u20AC',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: pagato ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text(
                    p['dataPagamento'] != null
                        ? DateFormat('dd/MM/yy').format(DateTime.parse(p['dataPagamento']))
                        : '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    pagato ? 'Pagato' : 'Da pagare',
                    style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: pagato ? Colors.green : Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePaymentDialog(BuildContext context) {
    final descrizioneCtrl = TextEditingController();
    final importoCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int? selectedPlayerId;
    bool pagato = false;

    final players = context.read<PlayersProvider>().players;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuovo Pagamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selezione giocatore
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Giocatore *'),
                  items: players.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.displayName),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedPlayerId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descrizioneCtrl,
                  decoration: const InputDecoration(labelText: 'Descrizione *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Importo *',
                    prefixText: '\u20AC ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Gia\' pagato'),
                  value: pagato,
                  onChanged: (val) => setDialogState(() => pagato = val),
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
                if (selectedPlayerId == null ||
                    descrizioneCtrl.text.trim().isEmpty ||
                    importoCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final auth = context.read<AuthProvider>();
                  await auth.apiClient.dio.post(
                    ApiConstants.playerPayments(selectedPlayerId!),
                    data: {
                      'descrizione': descrizioneCtrl.text.trim(),
                      'importo': double.tryParse(importoCtrl.text) ?? 0,
                      'dataPagamento': DateTime.now().toIso8601String(),
                      'pagato': pagato,
                      'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    },
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pagamento creato!')));
                    _loadData();
                  }
                } catch (_) {}
              },
              child: const Text('Crea'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, dynamic payment) {
    final pagato = payment['pagato'] == true;
    final paymentId = payment['id'] as int;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment['descrizione'] ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('${payment['nomeGiocatore']} - ${((payment['importo'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} \u20AC'),
              if (payment['note'] != null && (payment['note'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Note: ${payment['note']}',
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(
                  pagato ? Icons.cancel : Icons.check_circle,
                  color: pagato ? Colors.orange : Colors.green,
                ),
                title: Text(pagato ? 'Segna come NON pagato' : 'Segna come PAGATO'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final auth = context.read<AuthProvider>();
                    await auth.apiClient.dio.put(
                      ApiConstants.payment(paymentId),
                      data: {'pagato': !pagato},
                    );
                    if (mounted) _loadData();
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
