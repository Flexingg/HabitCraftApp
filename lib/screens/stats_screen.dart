import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../bridge_api.dart';
import '../habit_health.dart';
import '../theme.dart';

class StatsScreen extends StatefulWidget {
  final BridgeApi api;
  const StatsScreen({super.key, required this.api});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with WidgetsBindingObserver {
  final _health = HabitHealth();
  String? _err;
  TodayHealth? _today;
  List<TrendPoint> _trend = [];
  List<dynamic> _incentives = [];
  List<dynamic> _history = [];
  String _metric = 'STEPS'; // trend metric selector

  static const _weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() { _err = null; });
    await _health.configure();
    final granted = await _health.coreGranted();
    if (granted) {
      _today = await _health.readToday();
      _trend = await _health.readTrend(7);
    }
    try {
      _incentives = await widget.api.incentives();
      _history = await widget.api.history(limit: 200);
    } on BridgeException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  double? _metricValue(String metric, TodayHealth h) => switch (metric) {
        'STEPS' => h.steps.toDouble(),
        'DISTANCE_KM' => h.distanceKm,
        'CALORIES' => h.energyKcal,
        _ => null,
      };

  List<double> _trendSeries() => [
        for (final t in _trend)
          switch (_metric) { 'DISTANCE_KM' => t.distanceKm, 'CALORIES' => t.energyKcal, _ => t.steps.toDouble() }
      ];

  DateTime _parseEpoch(num e) =>
      DateTime.fromMillisecondsSinceEpoch(e > 1e12 ? e.toInt() : e.toInt() * 1000);

  /// Rewards dispensed per calendar day over the last 7 days (oldest first).
  List<int> _rewardsByDay() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 6);
    final days = List<int>.filled(7, 0);
    for (final r in _history) {
      if (r['status'] != 'DISPENSED') continue;
      final dt = _parseEpoch((r['created_at'] as num));
      final idx = dt.difference(start).inDays;
      if (idx >= 0 && idx < 7) days[idx]++;
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _load, child: ListView(
      padding: const EdgeInsets.all(16), children: [
        Text('Stats', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Your activity vs targets, and rewards earned.',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (_err != null)
          Card(child: Padding(padding: const EdgeInsets.all(12),
            child: Text('⚠ Bridge unreachable ($_err)', style: const TextStyle(color: Colors.orangeAccent))))
        else ...[
          _trendCard(),
          const SizedBox(height: 16),
          _targetsCard(),
          const SizedBox(height: 16),
          _rewardsCard(),
        ],
      ],
    ));
  }

  Widget _trendCard() {
    final series = _trendSeries();
    final has = series.any((s) => s > 0);
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'STEPS', label: Text('Steps')),
            ButtonSegment(value: 'DISTANCE_KM', label: Text('km')),
            ButtonSegment(value: 'CALORIES', label: Text('kcal')),
          ],
          selected: {_metric},
          onSelectionChanged: (s) => setState(() => _metric = s.first),
        ),
        const SizedBox(height: 12),
        if (!has)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No activity in the last 7 days yet.', style: TextStyle(color: Colors.grey))))
        else
          SizedBox(height: 200, child: _bar(series)),
      ]),
    ));
  }

  Widget _bar(List<double> series) {
    final maxY = (series.isEmpty ? 1.0 : series.reduce((a, b) => a > b ? a : b));
    final cap = maxY <= 0 ? 1.0 : maxY * 1.15;
    final color = _metric == 'CALORIES'
        ? HabitTheme.gold : (_metric == 'DISTANCE_KM' ? HabitTheme.diamond : HabitTheme.emeraldBright);
    return BarChart(BarChartData(
      maxY: cap,
      alignment: BarChartAlignment.spaceAround,
      barGroups: [
        for (var i = 0; i < series.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: series[i], width: 14, color: series[i] > 0 ? color : const Color(0xFF4A5058))
          ]),
      ],
      gridData: const FlGridData(show: true, drawVerticalLine: false, drawHorizontalLine: true),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34,
            getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                style: const TextStyle(color: Colors.grey, fontSize: 10)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i < 0 || i >= _trend.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text(_weekday[_trend[i].date.weekday - 1],
                      style: const TextStyle(color: Colors.grey, fontSize: 10)));
            })),
      ),
      barTouchData: BarTouchData(enabled: false),
    ));
  }

  Widget _targetsCard() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Today vs targets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_incentives.isEmpty)
          const Text('No incentives defined yet (Rewards tab).', style: TextStyle(color: Colors.grey))
        else if (_today == null)
          const Text('Grant Health Connect access to compare against your targets.',
              style: TextStyle(color: Colors.grey))
        else
          ..._incentives.map((inc) {
            final metric = inc['metric'] as String;
            final target = (inc['target_value'] as num).toDouble();
            final val = _metricValue(metric, _today!);
            if (val == null) {
              return ListTile(contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: Colors.grey),
                  title: Text(inc['name'] as String),
                  subtitle: const Text('metric not read on this device', style: TextStyle(color: Colors.grey, fontSize: 12)));
            }
            final p = (val / (target <= 0 ? 1 : target)).clamp(0.0, 1.0);
            final done = val >= target;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(done ? Icons.check_circle : Icons.flag_outlined,
                      color: done ? HabitTheme.emerald : HabitTheme.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(inc['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('${_fmt(val)} / ${_fmt(target)} ${inc['unit']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: p, minHeight: 6,
                    backgroundColor: const Color(0xFF3A3F45),
                    color: done ? HabitTheme.emerald : HabitTheme.gold),
              ]),
            );
          }),
      ]),
    ));
  }

  Widget _rewardsCard() {
    final byDay = _rewardsByDay();
    final total = byDay.fold<int>(0, (a, b) => a + b);
    final dispensed = _history.where((r) => r['status'] == 'DISPENSED').length;
    final pending = _history.where((r) => r['status'] == 'PENDING').length;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rewards earned', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Wrap(spacing: 24, children: [
          _numstat('$dispensed', 'dispensed', HabitTheme.emerald),
          _numstat('$pending', 'pending', HabitTheme.gold),
          _numstat('$total', 'last 7 days', HabitTheme.diamond),
        ]),
        const SizedBox(height: 12),
        if (total == 0)
          const Text('No rewards dispensed in the last 7 days.', style: TextStyle(color: Colors.grey))
        else
          SizedBox(height: 170, child: _bar(byDay.map((e) => e.toDouble()).toList())),
      ]),
    ));
  }

  Widget _numstat(String v, String label, Color c) {
    return Column(children: [
      Text(v, style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
