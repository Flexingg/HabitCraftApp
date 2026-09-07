import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge_api.dart';
import '../habit_health.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  final BridgeApi api;
  final bool isAdmin;
  final bool linked;
  final String? pendingCode;
  final String? pendingName;
  final Future<void> Function(String name) onLink;
  final Future<void> Function() onRefresh;
  final VoidCallback onCancelPending;
  final ValueChanged<BuildContext> onOpenSettings;
  const HomeScreen({super.key, required this.api, required this.isAdmin, required this.linked,
    this.pendingCode, this.pendingName, required this.onLink, required this.onRefresh,
    required this.onCancelPending, required this.onOpenSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (widget.pendingCode != null) _startPoll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPoll();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.pendingCode != null && old.pendingCode == null) {
      _startPoll();
    } else if (widget.pendingCode == null) {
      _stopPoll();
    }
  }

  void _startPoll() {
    _stopPoll();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => widget.onRefresh());
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when the user returns from the Health Connect / Settings screens.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() { _busy = true; });
    await _health.configure();
    _hcAvailable = await _health.isAvailable();
    if (_hcAvailable) {
      _perm = await _health.coreGranted();
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
      await _health.install();
      setState(() => _hcAvailable = false);
      await _load();
      return;
    }
    final outcome = await _health.requestPermission();
    switch (outcome) {
      case PermissionOutcome.granted:
        _toast('Health Connect access granted.');
      case PermissionOutcome.denied:
        await _showDeniedHelp();
      case PermissionOutcome.healthConnectMissing:
        _toast('Health Connect is not installed. Opening Play Store…');
        await _health.install();
      case PermissionOutcome.error:
        _toast('Something went wrong requesting access. Check the Android log.');
    }
    setState(() {});
    await _load();
  }

  /// The in-app request didn't surface the Health Connect UI (device-specific).
  /// Give a one-tap shortcut straight into Health Connect's permission screen.
  Future<void> _showDeniedHelp() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Health Connect access'),
        content: const Text(
            'Tap "Open Health Connect", then allow the data types you want to share. '
            'That flips the switch here — no digging through Android settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Health Connect')),
        ],
      ),
    );
    if (go == true) {
      final opened = await _health.openPermissions();
      _toast(opened ? 'Opened Health Connect. Flip on what you want, then refresh.' : 'Could not open Health Connect directly.');
    }
  }

  double? _valueFor(String metric, TodayHealth h) => switch (metric) {
        'STEPS' => h.steps.toDouble(),
        'DISTANCE_KM' => h.distanceKm,
        'CALORIES' => h.energyKcal,
        'TOTAL_CALORIES' => h.totalKcal,
        'ACTIVE_MINUTES' => h.exerciseMinutes.toDouble(),
        'SLEEP_HOURS' => h.sleepHours,
        'WORKOUTS' => h.workouts.toDouble(),
        _ => null,
      };

  Future<void> _fileIncentive(String id) async {
    try { await widget.api.autoFile(id); await _load(); }
    on BridgeException catch (e) { _toast(e.message); }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _header(),
      const SizedBox(height: 16),
      if (!widget.linked)
        (widget.pendingCode != null) ? _pendingPanel() : _linkPanel()
      else
        _playerBanner(),
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
    ]);
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

  Widget _pendingPanel() {
    final code = widget.pendingCode ?? '';
    final name = widget.pendingName ?? 'that account';
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirm in Minecraft', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Join the server and run this command as $name to finish linking:',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF101412),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: HabitTheme.emerald, width: 1.5),
          ),
          child: SelectableText('/habitcraft confirm $code',
              textAlign: TextAlign.center,
              style: const TextStyle(color: HabitTheme.emeraldBright,
                  fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text('Waiting for in-game confirmation — this updates automatically.',
              style: const TextStyle(color: Colors.grey, fontSize: 13))),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: widget.onRefresh, child: const Text('Check now')),
          TextButton(onPressed: widget.onCancelPending, child: const Text('Cancel')),
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
          _action('Health Connect is not installed on this phone.',
              Icons.health_and_safety, 'Install Health Connect', _connectHealth)
        else if (!_perm)
          _action('Allow HabitCraft to read your health data.',
              Icons.health_and_safety, 'Connect Health Connect', _connectHealth)
        else if (_today == null || !_today!.any)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('No Health Connect data recorded yet today.',
                style: TextStyle(color: Colors.grey)),
          ])
        else
          Wrap(spacing: 18, runSpacing: 14, children: _statTiles(_today!)),
      ]),
    ));
  }

  Widget _action(String text, IconData icon, String buttonLabel, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 10),
      Row(children: [
        FilledButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(buttonLabel)),
        if (!_perm && _hcAvailable) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: () => _health.openPermissions(), child: const Text('Open Health Connect')),
        ],
      ]),
    ]);
  }

  List<Widget> _statTiles(TodayHealth h) {
    final List<(IconData, String, String)> raw = [
      (Icons.directions_walk, h.steps.toString(), 'steps'),
      (Icons.straighten, h.distanceKm.toStringAsFixed(2), 'km'),
      (Icons.local_fire_department, h.energyKcal.round().toString(), 'kcal active'),
      if (h.totalKcal > 0) (Icons.whatshot, h.totalKcal.round().toString(), 'kcal total'),
      if (h.sleepHours > 0) (Icons.bedtime, h.sleepHours.toStringAsFixed(1), 'h sleep'),
      if (h.exerciseMinutes > 0) (Icons.fitness_center, '${h.exerciseMinutes}', 'min active'),
      if (h.workouts > 0) (Icons.directions_run, '${h.workouts}', 'workouts'),
      if (h.weightKg != null) (Icons.monitor_weight, h.weightKg!.toStringAsFixed(1), 'kg'),
      if (h.restingHr != null) (Icons.favorite, h.restingHr!.round().toString(), 'bpm rest'),
      if (h.bodyTempC != null) (Icons.thermostat, '${h.bodyTempC!.toStringAsFixed(1)}°', 'temp'),
      if (h.spo2 != null) (Icons.air, '${h.spo2!.round()}%', 'SpO2'),
      if (h.systolic != null) (Icons.bloodtype, '${h.systolic!.round()}/${h.diastolic?.round() ?? '–'}', 'BP'),
      if (h.hrvMs != null) (Icons.monitor_heart, '${h.hrvMs!.round()}', 'HRV ms'),
    ];
    return raw.map((t) => SizedBox(width: 92, child: Column(children: [
      Icon(t.$1, color: HabitTheme.emeraldBright, size: 26),
      const SizedBox(height: 4),
      Text(t.$2, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(t.$3, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ]))).toList();
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
              : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} / ${target.toStringAsFixed(target == target.roundToDouble() ? 0 : 1)} ${inc['unit']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        if (earned)
          const Text('✓ earned', style: TextStyle(color: HabitTheme.emerald))
        else if (met && auto)
          FilledButton(onPressed: _busy ? null : () => _fileIncentive(id), child: const Text('Claim'))
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
