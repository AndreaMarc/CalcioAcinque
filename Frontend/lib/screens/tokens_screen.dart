import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/constants/api_constants.dart';
import '../models/dashboard_model.dart';

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
              .map((e) => PlayerTokenSummary.fromJson(e)).toList();
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final useGettoni = context.watch<DashboardProvider>().useGettoni;
    if (!useGettoni) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.toll, size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Sistema gettoni disabilitato',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Puoi attivarlo nelle Impostazioni del team',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 13)),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summaries.isEmpty) {
      return const Center(child: Text('Nessun giocatore'));
    }

    final sorted = List<PlayerTokenSummary>.from(_summaries)
      ..sort((a, b) => b.gettoniRimanenti.compareTo(a.gettoniRimanenti));

    return RefreshIndicator(
      onRefresh: _loadTokens,
      child: ListView.builder(
        itemCount: sorted.length + 1,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/payments'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Gestione Pagamenti'),
              ),
            );
          }
          index = index - 1;
          final p = sorted[index];
          return Card(
            child: ListTile(
              onTap: () => context.push('/player/${p.playerId}'),
              leading: CircleAvatar(
                backgroundColor: p.gettoniRimanenti > 0
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                child: Text(
                  '${p.gettoniRimanenti}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: p.gettoniRimanenti > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              title: Text(p.soprannome ?? p.nome),
              subtitle: p.gettoniTotali > 0
                  ? LinearProgressIndicator(
                      value: p.gettoniRimanenti.toDouble() / p.gettoniTotali.toDouble(),
                      borderRadius: BorderRadius.circular(4),
                      color: p.gettoniRimanenti > 0 ? null : Colors.red,
                    )
                  : null,
              trailing: Text(
                '${p.gettoniRimanenti} / ${p.gettoniTotali}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        },
      ),
    );
  }
}
