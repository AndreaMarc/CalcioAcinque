import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../core/constants/api_constants.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _teamStats;
  bool _isLoading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final resp = await auth.apiClient.dio.get(
        ApiConstants.teamStats(auth.teamId));
      if (resp.data['success'] == true) {
        setState(() => _teamStats = resp.data['data']);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamStats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64,
              color: cs.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Nessuna statistica disponibile',
              style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Completa qualche partita per vedere le statistiche',
              style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7),
                fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: Column(
        children: [
          // Tab bar
          Container(
            color: cs.surface,
            child: TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Classifica', icon: Icon(Icons.emoji_events, size: 20)),
                Tab(text: 'Grafici', icon: Icon(Icons.bar_chart, size: 20)),
                Tab(text: 'Partite', icon: Icon(Icons.timeline, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildClassifica(context),
                _buildGrafici(context),
                _buildStorico(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──── TAB 1: CLASSIFICA ────
  Widget _buildClassifica(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final classifica = (_teamStats!['classifica'] as List?) ?? [];
    final totPartite = _teamStats!['totalePartite'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary.withOpacity(0.08), cs.primary.withOpacity(0.02)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Text('Riepilogo Stagione', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('Partite', '$totPartite', Icons.sports_soccer, cs.primary),
                  _summaryItem('Goal', '${_teamStats!['totaleGoal'] ?? 0}',
                    Icons.sports_soccer, Colors.green.shade700),
                  _summaryItem('Assist', '${_teamStats!['totaleAssist'] ?? 0}',
                    Icons.handshake, Colors.purple.shade600),
                  _summaryItem('Subiti', '${_teamStats!['totaleGoalSubiti'] ?? 0}',
                    Icons.shield, Colors.red.shade600),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('Autogoal', '${_teamStats!['totaleAutogoal'] ?? 0}',
                    Icons.sports_soccer, Colors.orange),
                  _summaryItem('Ammon.', '${_teamStats!['totaleAmmonizioni'] ?? 0}',
                    Icons.square, Colors.amber.shade700),
                  _summaryItem('Espuls.', '${_teamStats!['totaleEspulsioni'] ?? 0}',
                    Icons.square, Colors.red.shade800),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Classifica marcatori
        Text('Classifica Marcatori', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 8),
        ...List.generate(classifica.length, (i) {
          final p = classifica[i];
          return _buildPlayerRankRow(context, i, p);
        }),
      ],
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildPlayerRankRow(BuildContext context, int index, Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;
    final nome = p['soprannome'] ?? p['nomeGiocatore'] ?? '';
    final goal = p['totaleGoal'] ?? 0;
    final assist = p['totaleAssist'] ?? 0;
    final partite = p['partiteGiocate'] ?? 0;

    Color? rankColor;
    if (index == 0) rankColor = Colors.amber.shade600;
    else if (index == 1) rankColor = Colors.grey.shade500;
    else if (index == 2) rankColor = Colors.brown.shade400;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: rankColor != null
                ? Icon(Icons.emoji_events, color: rankColor, size: 22)
                : Text('${index + 1}', textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$partite partite', style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            _miniStat(Icons.sports_soccer, '$goal', Colors.green.shade700),
            const SizedBox(width: 8),
            _miniStat(Icons.handshake_outlined, '$assist', Colors.purple.shade600),
            const SizedBox(width: 8),
            if ((p['totaleAmmonizioni'] ?? 0) > 0)
              _miniStat(Icons.square, '${p['totaleAmmonizioni']}', Colors.amber.shade700),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
          color: color)),
      ],
    );
  }

  // ──── TAB 2: GRAFICI ────
  Widget _buildGrafici(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final classifica = (_teamStats!['classifica'] as List?) ?? [];

    if (classifica.isEmpty) {
      return Center(
        child: Text('Nessun dato disponibile',
          style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    // Top 5 per i grafici
    final top5Goal = classifica.take(5).toList();
    final top5Assist = List.from(classifica);
    top5Assist.sort((a, b) =>
      ((b['totaleAssist'] ?? 0) as int).compareTo((a['totaleAssist'] ?? 0) as int));
    final top5AssistList = top5Assist.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Goal chart
        Text('Top Marcatori', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _buildBarChart(context, top5Goal, 'totaleGoal',
            Colors.green.shade600),
        ),
        const SizedBox(height: 28),

        // Assist chart
        Text('Top Assist', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _buildBarChart(context, top5AssistList, 'totaleAssist',
            Colors.purple.shade600),
        ),
        const SizedBox(height: 28),

        // Goal vs partite - radar-style
        Text('Goal + Assist per Giocatore', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: _buildGroupedBarChart(context, top5Goal),
        ),
        const SizedBox(height: 28),

        // Distribuzione presenze (pie chart)
        Text('Presenze per Giocatore', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _buildPresenzePieChart(context, classifica),
        ),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context, List data, String field, Color color) {
    final cs = Theme.of(context).colorScheme;
    if (data.isEmpty) return const SizedBox();

    final maxVal = data.fold<double>(0, (m, p) {
      final v = (p[field] ?? 0) as int;
      return v > m ? v.toDouble() : m;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal + 1,
        barGroups: List.generate(data.length, (i) {
          final val = (data[i][field] ?? 0) as int;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: val.toDouble(),
              color: color,
              width: 28,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            ),
          ]);
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 40,
              getTitlesWidget: (v, meta) {
                if (v.toInt() >= data.length) return const SizedBox();
                final nome = data[v.toInt()]['soprannome'] ??
                  data[v.toInt()]['nomeGiocatore'] ?? '';
                final short = nome.length > 8 ? '${nome.substring(0, 8)}..' : nome;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(short, style: TextStyle(fontSize: 10,
                    color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          horizontalInterval: 1,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: cs.outlineVariant.withOpacity(0.3), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildGroupedBarChart(BuildContext context, List data) {
    final cs = Theme.of(context).colorScheme;
    if (data.isEmpty) return const SizedBox();

    final maxVal = data.fold<double>(0, (m, p) {
      final g = (p['totaleGoal'] ?? 0) as int;
      final a = (p['totaleAssist'] ?? 0) as int;
      final v = g > a ? g : a;
      return v > m ? v.toDouble() : m;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal + 1,
        barGroups: List.generate(data.length, (i) {
          final goal = (data[i]['totaleGoal'] ?? 0) as int;
          final assist = (data[i]['totaleAssist'] ?? 0) as int;
          return BarChartGroupData(x: i, barsSpace: 4, barRods: [
            BarChartRodData(
              toY: goal.toDouble(), color: Colors.green.shade600, width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: assist.toDouble(), color: Colors.purple.shade600, width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
          ]);
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 40,
              getTitlesWidget: (v, meta) {
                if (v.toInt() >= data.length) return const SizedBox();
                final nome = data[v.toInt()]['soprannome'] ??
                  data[v.toInt()]['nomeGiocatore'] ?? '';
                final short = nome.length > 8 ? '${nome.substring(0, 8)}..' : nome;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(short, style: TextStyle(fontSize: 10,
                    color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          horizontalInterval: 1, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: cs.outlineVariant.withOpacity(0.3), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPresenzePieChart(BuildContext context, List classifica) {
    final cs = Theme.of(context).colorScheme;
    final colors = [
      cs.primary, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.red, Colors.indigo, Colors.pink,
      Colors.cyan, Colors.brown,
    ];

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < classifica.length && i < 8; i++) {
      final p = classifica[i];
      final presenze = (p['partitePresente'] ?? 0) as int;
      if (presenze == 0) continue;
      final nome = p['soprannome'] ?? p['nomeGiocatore'] ?? '';
      final short = nome.length > 6 ? '${nome.substring(0, 6)}..' : nome;
      sections.add(PieChartSectionData(
        value: presenze.toDouble(),
        title: '$short\n$presenze',
        color: colors[i % colors.length],
        radius: 80,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
          color: Colors.white),
        titlePositionPercentageOffset: 0.55,
      ));
    }

    if (sections.isEmpty) {
      return Center(child: Text('Nessun dato',
        style: TextStyle(color: cs.onSurfaceVariant)));
    }

    return PieChart(PieChartData(
      sections: sections,
      sectionsSpace: 2,
      centerSpaceRadius: 30,
    ));
  }

  // ──── TAB 3: STORICO PARTITE ────
  Widget _buildStorico(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final storico = (_teamStats!['storicoPartite'] as List?) ?? [];

    if (storico.isEmpty) {
      return Center(
        child: Text('Nessuna partita conclusa',
          style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Goal fatti vs subiti line chart
        Text('Andamento Goal', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 4),
        Row(
          children: [
            _legendItem('Fatti', Colors.green.shade600),
            const SizedBox(width: 16),
            _legendItem('Subiti', Colors.red.shade600),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _buildGoalLineChart(context, storico),
        ),
        const SizedBox(height: 28),

        // Presenti per partita
        Text('Presenti per Giornata', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _buildPresentiChart(context, storico),
        ),
        const SizedBox(height: 20),

        // Lista partite
        Text('Dettaglio Partite', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
        const SizedBox(height: 8),
        ...storico.reversed.map((m) => _buildMatchCard(context, m)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildGoalLineChart(BuildContext context, List storico) {
    final cs = Theme.of(context).colorScheme;

    final maxY = storico.fold<double>(0, (m, s) {
      final gf = (s['goalFatti'] ?? 0) as int;
      final gs = (s['goalSubiti'] ?? 0) as int;
      final v = gf > gs ? gf : gs;
      return v > m ? v.toDouble() : m;
    });

    return LineChart(
      LineChartData(
        maxY: maxY + 1,
        minY: 0,
        lineBarsData: [
          // Goal fatti
          LineChartBarData(
            spots: List.generate(storico.length, (i) =>
              FlSpot(i.toDouble(), ((storico[i]['goalFatti'] ?? 0) as int).toDouble())),
            color: Colors.green.shade600,
            barWidth: 3,
            isCurved: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true, color: Colors.green.withOpacity(0.1)),
          ),
          // Goal subiti
          LineChartBarData(
            spots: List.generate(storico.length, (i) =>
              FlSpot(i.toDouble(), ((storico[i]['goalSubiti'] ?? 0) as int).toDouble())),
            color: Colors.red.shade600,
            barWidth: 3,
            isCurved: true,
            dotData: const FlDotData(show: true),
            dashArray: [5, 3],
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30, interval: 1,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              getTitlesWidget: (v, meta) {
                if (v.toInt() >= storico.length) return const SizedBox();
                return Text('G${storico[v.toInt()]['numeroGiornata']}',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));
              },
            ),
          ),
        ),
        gridData: FlGridData(
          horizontalInterval: 1, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: cs.outlineVariant.withOpacity(0.3), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPresentiChart(BuildContext context, List storico) {
    final cs = Theme.of(context).colorScheme;

    final maxY = storico.fold<double>(0, (m, s) {
      final v = (s['presenti'] ?? 0) as int;
      return v > m ? v.toDouble() : m;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY + 1,
        barGroups: List.generate(storico.length, (i) {
          final val = (storico[i]['presenti'] ?? 0) as int;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: val.toDouble(), color: cs.primary, width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
          ]);
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30, interval: 1,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              getTitlesWidget: (v, meta) {
                if (v.toInt() >= storico.length) return const SizedBox();
                return Text('G${storico[v.toInt()]['numeroGiornata']}',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));
              },
            ),
          ),
        ),
        gridData: FlGridData(
          horizontalInterval: 1, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: cs.outlineVariant.withOpacity(0.3), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, dynamic m) {
    final cs = Theme.of(context).colorScheme;
    final gf = m['goalFatti'] ?? 0;
    final gs = m['goalSubiti'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('G${m['numeroGiornata']}', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: cs.onPrimaryContainer)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Giornata ${m['numeroGiornata']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${m['presenti']} presenti',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: gf > gs ? Colors.green.withOpacity(0.12)
                  : gf < gs ? Colors.red.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$gf - $gs', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16,
                color: gf > gs ? Colors.green.shade700
                  : gf < gs ? Colors.red.shade700
                  : cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
