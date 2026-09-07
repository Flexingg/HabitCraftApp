import 'package:flutter/material.dart';

import '../bridge_api.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  final BridgeApi api;
  final bool isAdmin;
  const HistoryScreen({super.key, required this.api, required this.isAdmin});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _rows = [];
  bool _busy = true;
  String? _err;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final h = await widget.api.history(limit: 100);
      if (mounted) setState(() { _rows = h; _busy = false; _err = null; });
    } on BridgeException catch (e) {
      if (mounted) setState(() { _busy = false; _err = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('Earning history', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      if (_err != null)
        Card(child: ListTile(
          leading: const Icon(Icons.info, color: Colors.orangeAccent),
          title: Text('$_err'),
          subtitle: const Text('Link your Minecraft account on the Today tab first.'),
        ))
      else if (_busy)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_rows.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24),
            child: Text('No rewards earned yet.', style: TextStyle(color: Colors.grey))))
      else
        for (final r in _rows) _rowCard(r),
    ]);
  }

  Widget _rowCard(dynamic r) {
    final dispensed = r['status'] == 'DISPENSED';
    final type = r['type'] as String;
    final pay = r['payload'] as Map;
    final when = DateTime.fromMillisecondsSinceEpoch((r['created_at'] as num).toInt());
    return Card(child: ListTile(
      leading: Icon(_icon(type), color: dispensed ? HabitTheme.emerald : HabitTheme.gold),
      title: Text('${r['activity_id']} · ${_describe(type, pay)}',
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text('${_fmt(when)} · ${dispensed ? 'delivered' : 'queued'}'),
      trailing: Text(dispensed ? '✓' : '⏳',
          style: TextStyle(color: dispensed ? HabitTheme.emerald : HabitTheme.gold)),
    ));
  }

  IconData _icon(String type) => switch (type) {
        'MONEY' => Icons.attach_money,
        'ITEM' => Icons.inventory_2,
        'XP' => Icons.bolt,
        'COMMAND' => Icons.terminal,
        _ => Icons.star,
      };

  String _describe(String type, Map p) => switch (type) {
        'MONEY' => '${p['amount']} coins',
        'XP' => '${p['levels']} XP',
        'ITEM' => '${p['amount'] ?? 1}x ${p['material']}',
        'COMMAND' => 'custom effect',
        _ => type,
      };

  String _fmt(DateTime t) {
    final l = t.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
