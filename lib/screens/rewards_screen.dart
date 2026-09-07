import 'package:flutter/material.dart';

import '../bridge_api.dart';
import '../theme.dart';

class RewardsScreen extends StatefulWidget {
  final BridgeApi api;
  final bool isAdmin;
  const RewardsScreen({super.key, required this.api, required this.isAdmin});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<dynamic> _rewards = [];
  List<dynamic> _incentives = [];
  bool _busy = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.rewards();
      final i = await widget.api.incentives();
      if (mounted) setState(() { _rewards = r; _incentives = i; _busy = false; _err = null; });
    } on BridgeException catch (e) {
      if (mounted) setState(() { _busy = false; _err = e.message; });
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('Rewards & Incentives', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      if (!widget.isAdmin)
        const Card(child: ListTile(
          leading: Icon(Icons.lock, color: Colors.redAccent),
          title: Text('Admin only'),
          subtitle: Text('Link an op Minecraft account to manage rewards & incentives.'),
        ))
      else if (_err != null)
        Text('⚠ $_err', style: const TextStyle(color: Colors.orangeAccent))
      else if (_busy)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else ...[
        _sectionHeader('In-game reward packages', onAdd: _newReward),
        for (final r in _rewards) _rewardCard(r),
        const SizedBox(height: 24),
        _sectionHeader('Habit incentives (health threshold → reward)', onAdd: _newIncentive),
        for (final i in _incentives) _incentiveCard(i),
      ],
    ]);
  }

  Widget _sectionHeader(String title, {required VoidCallback onAdd}) {
    return Row(children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      IconButton.filledTonal(icon: const Icon(Icons.add), onPressed: onAdd, tooltip: 'Add'),
    ]);
  }

  String _desc(dynamic r) {
    final list = (r['rewards'] as List).map((x) {
      final t = (x['type'] as String);
      return switch (t) {
        'MONEY' => '${x['amount']} coins',
        'XP' => '${x['levels']} XP',
        'ITEM' => '${x['amount'] ?? 1}x ${x['material']}',
        'COMMAND' => 'cmd',
        _ => t,
      };
    }).join(', ');
    return list;
  }

  Widget _rewardCard(dynamic r) {
    final id = r['id'] as String;
    return Card(child: ListTile(
      leading: const Icon(Icons.card_giftcard, color: HabitTheme.emerald),
      title: Text(r['name'].toString(), style: const TextStyle(color: Colors.white)),
      subtitle: Text(_desc(r), style: const TextStyle(fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editReward(r)),
        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
            onPressed: () => _deleteReward(id)),
      ]),
    ));
  }

  Widget _incentiveCard(dynamic i) {
    return Card(child: ListTile(
      leading: Icon(i['enabled'] == true ? Icons.flag : Icons.flag_outlined,
          color: HabitTheme.gold),
      title: Text(i['name'].toString(), style: const TextStyle(color: Colors.white)),
      subtitle: Text('${i['target_value']} ${i['unit']} ${i['metric']} → ${i['activity_id']}',
          style: const TextStyle(fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editIncentive(i)),
        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
            onPressed: () => _deleteIncentive(i['id'] as String)),
      ]),
    ));
  }

  Future<void> _deleteReward(String id) async {
    try { await widget.api.deleteReward(id); _load(); }
    on BridgeException catch (e) { _toast(e.message); }
  }
  Future<void> _deleteIncentive(String id) async {
    try { await widget.api.deleteIncentive(id); _load(); }
    on BridgeException catch (e) { _toast(e.message); }
  }

  void _newReward() => _openRewardEditor();
  void _editReward(dynamic r) => _openRewardEditor(initial: r);
  void _newIncentive() => _openIncentiveEditor();
  void _editIncentive(dynamic i) => _openIncentiveEditor(initial: i);

  Future<void> _openRewardEditor({dynamic initial}) async {
    await showDialog(context: context, builder: (_) => RewardEditorDialog(
      api: widget.api, initial: initial == null ? null : Map<String, dynamic>.from(initial)));
    _load();
  }
  Future<void> _openIncentiveEditor({dynamic initial}) async {
    await showDialog(context: context, builder: (_) => IncentiveEditorDialog(
      api: widget.api, rewardIds: _rewards.map((r) => r['id'] as String).toList(),
      initial: initial == null ? null : Map<String, dynamic>.from(initial)));
    _load();
  }
}

// ---------------------------------------------------------------------------

class RewardEditorDialog extends StatefulWidget {
  final BridgeApi api;
  final Map<String, dynamic>? initial;
  const RewardEditorDialog({super.key, required this.api, this.initial});
  @override State<RewardEditorDialog> createState() => _RewardEditorDialogState();
}

class _RewardEditorDialogState extends State<RewardEditorDialog> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _cooldown = TextEditingController(text: '0');
  late List<Map<String, dynamic>> _rewards;
  List<String> _items = [];

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _id.text = (init?['id'] ?? '') as String;
    _name.text = (init?['name'] ?? '') as String;
    _desc.text = (init?['description'] ?? '') as String;
    _cooldown.text = ((init?['cooldown_minutes'] ?? 0)).toString();
    _rewards = (init?['rewards'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final its = await widget.api.items();
      if (mounted && its.isNotEmpty) setState(() => _items = its);
    } on BridgeException {
      // bridge unreachable -> fall back to free-text material entry
    }
  }

  @override void dispose() { _id.dispose(); _name.dispose(); _desc.dispose(); _cooldown.dispose(); super.dispose(); }

  /// Autocomplete over the real server item list (from the bridge /items endpoint).
  Widget _materialField(Map<String, dynamic> r) {
    final editable = _items.isEmpty;
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue c) {
        if (editable) return const Iterable<String>.empty();
        final q = c.text.trim().toUpperCase();
        if (q.isEmpty) return _items.take(30);
        return _items.where((i) => i.contains(q)).take(50);
      },
      onSelected: (v) => r['material'] = v,
      fieldViewBuilder: (context, tc, focus, onSubmitted) {
        final cur = r['material'] as String?;
        if (cur != null && cur.isNotEmpty && tc.text.isEmpty) tc.text = cur;
        return TextField(
          controller: tc,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: editable ? 'Material (e.g. DIAMOND)' : 'Material — search real items',
            helperText: editable ? null : 'matches the server item registry',
          ),
          onChanged: (v) => r['material'] = v,
        );
      },
    );
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'name': _name.text.trim().isEmpty ? _id.text.trim() : _name.text.trim(),
      'description': _desc.text.trim(),
      'cooldown_minutes': int.tryParse(_cooldown.text) ?? 0,
      'rewards': _rewards,
    };
    if (!_editing) payload['id'] = _id.text.trim().toLowerCase();
    try {
      _editing
          ? await widget.api.updateReward(widget.initial!['id'] as String, payload)
          : await widget.api.createReward(payload);
      if (mounted) Navigator.pop(context);
    } on BridgeException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _addRewardRow() => setState(() => _rewards.add({'type': 'MONEY', 'amount': 100}));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit reward package' : 'New reward package'),
      content: SingleChildScrollView(child: SizedBox(width: 360, child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          if (!_editing) TextField(controller: _id, decoration: InputDecoration(labelText: 'ID (snake_case)', enabled: !_editing)),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 8),
          TextField(controller: _cooldown, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cooldown (minutes, 0 = none)')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Rewards', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(onPressed: _addRewardRow, icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
          for (var i = 0; i < _rewards.length; i++) _rewardRow(i),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _rewardRow(int idx) {
    final r = _rewards[idx];
    return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
      DropdownButtonFormField<String>(
        initialValue: r['type'] as String,
        decoration: const InputDecoration(labelText: 'Type'),
        items: const ['MONEY','XP','ITEM','COMMAND']
            .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() {
          r['type'] = v!;
          if (v == 'MONEY') r['amount'] = r['amount'] ?? 100;
          if (v == 'XP') r['levels'] = r['levels'] ?? 1;
        }),
      ),
      const SizedBox(height: 4),
      if (r['type'] == 'MONEY')
        TextField(keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
            onChanged: (v) => r['amount'] = double.tryParse(v) ?? 0),
      if (r['type'] == 'XP')
        TextField(keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Levels'),
            onChanged: (v) => r['levels'] = int.tryParse(v) ?? 0),
      if (r['type'] == 'ITEM') ...[
        _materialField(r),
        TextField(keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
            onChanged: (v) => r['amount'] = int.tryParse(v) ?? 1),
      ],
      if (r['type'] == 'COMMAND')
        TextField(decoration: const InputDecoration(labelText: 'Console command ({player})'),
            onChanged: (v) => r['command'] = v),
    ])));
  }
}

// ---------------------------------------------------------------------------

class IncentiveEditorDialog extends StatefulWidget {
  final BridgeApi api;
  final List<String> rewardIds;
  final Map<String, dynamic>? initial;
  const IncentiveEditorDialog({super.key, required this.api, required this.rewardIds, this.initial});
  @override State<IncentiveEditorDialog> createState() => _IncentiveEditorDialogState();
}

class _IncentiveEditorDialogState extends State<IncentiveEditorDialog> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _metric = 'STEPS';
  String _activity = '';
  bool _auto = true;

  static const _metrics = ['STEPS','ACTIVE_MINUTES','SLEEP_HOURS','DISTANCE_KM','WORKOUTS','CALORIES'];

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name.text = (i?['name'] ?? '') as String;
    _target.text = (i?['target_value'] ?? '').toString();
    _metric = (i?['metric'] ?? 'STEPS') as String;
    _activity = (i?['activity_id'] ?? '') as String;
    _auto = (i?['auto_file'] ?? true) == true;
    if (_activity.isEmpty && widget.rewardIds.isNotEmpty) _activity = widget.rewardIds.first;
  }
  @override void dispose() { _name.dispose(); _target.dispose(); super.dispose(); }

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'name': _name.text.trim().isEmpty ? _metric : _name.text.trim(),
      'metric': _metric,
      'target_value': double.tryParse(_target.text) ?? 0,
      'activity_id': _activity,
      'auto_file': _auto,
    };
    try {
      _editing ? await widget.api.updateIncentive(widget.initial!['id'] as String, payload)
          : await widget.api.createIncentive(payload);
      if (mounted) Navigator.pop(context);
    } on BridgeException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit incentive' : 'New incentive'),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _metric,
          decoration: const InputDecoration(labelText: 'Health metric'),
          items: _metrics.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _metric = v!),
        ),
        const SizedBox(height: 8),
        TextField(controller: _target, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target value')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _activity,
          decoration: const InputDecoration(labelText: 'Reward package'),
          items: widget.rewardIds.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => _activity = v ?? ''),
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Auto-file when met'),
          value: _auto, onChanged: (v) => setState(() => _auto = v)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
