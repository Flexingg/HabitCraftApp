import 'package:flutter/material.dart';

import '../bridge_api.dart';
import '../habit_health.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  final BridgeApi api;
  final bool isAdmin;
  final bool linked;
  final Future<void> Function(String name) onLink;
  final Future<void> Function() onRefresh;
  final ValueChanged<BuildContext> onOpenSettings;
  const HomeScreen({super.key, required this.api, required this.isAdmin, required this.linked,
    required this.onLink, required this.onRefresh, required this.onOpenSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _health = HabitHealth();
  final _linkCtrl = TextEditingController();

  bool _hcAvailable = false;
  bool _perm = false;
  TodayHealth? _today;
  String? _linkedName;
  List<dynamic> _incentives = [];
  List<String> _filedToday = [];
  bool _busy = true;
  String? _bridgeErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _busy = true; });
    await _health.configure();
    _hcAvailable = await _health.isAvailable();
    if (_hcAvailable) {
      _perm = await _health.hasPermission();
      if (_perm) _today = await _health.readToday();
    }

    List<dynamic> incentives = [];
    List<String> filed = [];
    String? linkedName;
    try {
      incentives = await widget.api.incentives();
      final t = await widget.api.eventsToday();
      filed = (t['auto_filed'] as List).cast<String>();
      final cur = await widget.api.currentPlayer();
      linkedName = (cur?['name'] as String?) ?? (widget.linked ? 'your player' : null);
      _bridgeErr = null;
    } on BridgeException catch (e) {
      _bridgeErr = e.message;
    }

    if (mounted) {
      setState(() {
        _incentives = incentives;
        _filedToday = filed;
        _linkedName = linkedName;
        _busy = false;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _connectHealth() async {
    if (!await _health.isAvailable()) {
      _toast('Health Connect missing — opening Play Store to install it.');
      await _health.installHealthConnect();
      setState(() => _hcAvailable = false);
      await _load();
      return;
    }
    final outcome = await _health.requestPermission();
    switch (outcome) {
      case PermissionOutcome.granted:
        _toast('Health Connect access granted.');
      case PermissionOutcome.denied:
        _toast('Permission not granted. Please allow Health Connect access.');
      case PermissionOutcome.healthConnectMissing:
        _toast('Health Connect is not installed. Opening Play Store…');
        await _health.installHealthConnect();
      case PermissionOutcome.error:
        _toast('Something went wrong requesting access. Check the Android log.');
    }
    setState(() {});
    await _load();
  }

  double? _valueFor(String metric, TodayHealth h) => switch (metric) {
        'STEPS' => h.steps.toDouble(),
        'DISTANCE_KM' => h.distanceKm,
        'CALORIES' => h.energyKcal,
        _ => null,
      };

  Future<void> _fileIncentive(String id) async {
    try {
      await widget.api.autoFile(id);
      await _load();
    } on BridgeException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(),
        const SizedBox(height: 16),
        if (!widget.linked) _linkPanel() else _playerBanner(),
        const SizedBox(height: 16),
        _healthCard(),
        const SizedBox(height: 16),
        Text('Habit Incentives', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_incentives.isEmpty)
          const Text('No incentives defined yet. Add them on the Rewards tab.',
              style: TextStyle(color: Colors.grey))
        else
          ..._incentives.map(_incentiveTile),
      ],
    );
  }

  Widget _header() {
    return Row(children: [
      Text('⚡ ', style: TextStyle(color: HabitTheme.gold, fontSize: 22)),
      Text('Habit', style: Theme.of(context).textTheme.titleLarge!.copyWith(color: HabitTheme.emeraldBright)),
      Text('Craft', style: Theme.of(context).textTheme.titleLarge!.copyWith(color: HabitTheme.diamond)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.settings), tooltip: 'Bridge settings',
          onPressed: () => widget.onOpenSettings(context)),
    ]);
  }

  Widget _playerBanner() {
    final name = _linkedName ?? (widget.linked ? 'linked player' : '');
    return Card(child: ListTile(
      leading: const Icon(Icons.person, color: HabitTheme.emeraldBright),
      title: Text(widget.linked ? 'Playing as $name' : 'No Minecraft account linked'),
      subtitle: Text(widget.isAdmin
          ? 'Operator — full access to rewards & console.'
          : (widget.linked
              ? 'This player is not an op, so admin features are locked.'
              : 'Link your Minecraft username below to start earning.')),
      trailing: Icon(widget.isAdmin ? Icons.admin_panel_settings : Icons.person,
          color: widget.isAdmin ? HabitTheme.emerald : Colors.white24),
    ));
  }

  Widget _linkPanel() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Link your Minecraft account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Used to grant rewards and, if you are an op, unlock admin tools.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _linkCtrl,
            decoration: const InputDecoration(hintText: 'Minecraft username'),
          )),
          const SizedBox(width: 8),
          FilledButton(onPressed: () async {
            final name = _linkCtrl.text.trim();
            if (name.isEmpty) return;
            try {
              await widget.onLink(name);
              setState(() => _linkedName = name);
              await _load();
            } on BridgeException catch (e) { _toast(e.message); }
          }, child: const Text('Link')),
        ]),
      ]),
    ));
  }

  Widget _healthCard() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Today · Health Connect', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (_busy)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ]),
        const SizedBox(height: 8),
        if (_bridgeErr != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('⚠ Bridge unreachable ($_bridgeErr). Open settings (gear) to set the URL.',
                style: const TextStyle(color: Colors.orangeAccent)))
        else if (!_hcAvailable)
          _action('Health Connect is not installed.', Icons.health_and_safety,
              'Install Health Connect', _connectHealth)
        else if (!_perm)
          _action('Grant Health Connect access to read your real activity.', Icons.health_and_safety,
              'Connect Health Connect', _connectHealth)
        else if (_today == null)
          const Text('No Health Connect data recorded yet today.',
              style: TextStyle(color: Colors.grey))
        else
          Row(children: [
            _stat(Icons.directions_walk, '${_today!.steps}', 'steps'),
            _stat(Icons.straighten, _today!.distanceKm.toStringAsFixed(2), 'km'),
            _stat(Icons.local_fire_department, _today!.energyKcal.round().toString(), 'kcal'),
          ]),
      ]),
    ));
  }

  Widget _action(String text, IconData icon, String buttonLabel, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(buttonLabel)),
    ]);
  }

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(child: Column(children: [
      Icon(icon, color: HabitTheme.emeraldBright, size: 30),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]));
  }

  Widget _incentiveTile(dynamic inc) {
    final id = inc['id'] as String;
    final name = inc['name'] as String;
    final metric = inc['metric'] as String;
    final target = (inc['target_value'] as num).toDouble();
    final auto = inc['auto_file'] == true;
    final value = (_today != null) ? _valueFor(metric, _today!) : null;
    final met = value != null && value >= target;
    final earned = _filedToday.contains(id);

    return Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(earned ? Icons.check_circle : (met ? Icons.flag : Icons.flag_outlined),
            color: earned ? HabitTheme.emerald : (met ? HabitTheme.gold : Colors.grey)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value == null
              ? 'Metric not read on device yet'
              : '${value.round()} / ${target.round()} ${inc['unit']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        if (earned)
          const Text('✓ earned', style: TextStyle(color: HabitTheme.emerald))
        else if (met && auto)
          FilledButton(onPressed: _busy ? null : () => _fileIncentive(id),
              child: const Text('Claim'))
        else if (met)
          const Text('target met', style: TextStyle(color: HabitTheme.gold))
        else if (value != null)
          _progress(value, target),
      ]),
    ));
  }

  Widget _progress(double value, double target) {
    final p = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return SizedBox(width: 70, child: LinearProgressIndicator(value: p,
        minHeight: 6, backgroundColor: const Color(0xFF3A3F45), color: HabitTheme.emerald));
  }
}
