import 'package:flutter/material.dart';

import 'app_config.dart';
import 'bridge_api.dart';
import 'screens/console_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/stats_screen.dart';
import 'settings_dialog.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitCraftApp());
}

class HabitCraftApp extends StatefulWidget {
  const HabitCraftApp({super.key});
  @override
  State<HabitCraftApp> createState() => _HabitCraftAppState();
}

class _HabitCraftAppState extends State<HabitCraftApp> {
  int _tab = 0;
  AppConfig? _cfg;
  BridgeApi? _api;
  bool _loading = true;
  bool _isAdmin = false;
  bool _linked = false;
  String? _pendingCode;
  String? _pendingName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cfg = await AppConfig.load();
    final api = BridgeApi(baseUrl: cfg.baseUrl, apiKey: cfg.apiKey);
    bool admin = false, linked = false;
    try {
      final st = await api.status();
      linked = st['linked_player'] != null;
      admin = st['is_admin'] == true;
    } on BridgeException {
      // keep default unlinked; Home will show a connect error + settings
    }
    if (mounted) {
      setState(() {
        _cfg = cfg;
        _api = api;
        _loading = false;
        _isAdmin = admin;
        _linked = linked;
      });
    }
  }

  Future<void> _saveSettings(String baseUrl, String apiKey) async {
    final cfg = AppConfig(baseUrl: baseUrl, apiKey: apiKey);
    await cfg.save();
    setState(() => _loading = true);
    _cfg = cfg;
    _api = BridgeApi(baseUrl: cfg.baseUrl, apiKey: cfg.apiKey);
    await _refreshStatus();
  }

  Future<void> _link(String name) async {
    final api = _api!;
    final res = await api.linkPlayer(name);
    if (mounted) {
      setState(() {
        if (res['status'] == 'linked') {
          _linked = true;
          _isAdmin = res['is_admin'] == true;
          _pendingCode = null;
          _pendingName = null;
        } else {
          // pending -> show the in-game confirmation code
          _linked = false;
          _isAdmin = false;
          _pendingCode = res['code'] as String?;
          _pendingName = name;
        }
      });
    }
  }

  void _cancelPending() {
    setState(() {
      _pendingCode = null;
      _pendingName = null;
      _linked = false;
      _isAdmin = false;
    });
  }

  Future<void> _refreshStatus() async {
    final api = _api!;
    try {
      final st = await api.status();
      if (mounted) {
        setState(() {
          _linked = st['linked_player'] != null;
          _isAdmin = st['is_admin'] == true;
          if (_linked) { _pendingCode = null; _pendingName = null; }
          _loading = false;
        });
      }
    } on BridgeException {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitCraft',
      debugShowCheckedModeBanner: false,
      theme: HabitTheme.dark(),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _shell(context),
    );
  }

  Widget _shell(BuildContext context) {
    final api = _api!;
    final child = switch (_tab) {
      0 => HomeScreen(api: api, isAdmin: _isAdmin, linked: _linked,
          pendingCode: _pendingCode, pendingName: _pendingName,
          onLink: _link, onRefresh: _refreshStatus, onCancelPending: _cancelPending,
          onOpenSettings: (ctx) => _openSettings(ctx)),
      1 => RewardsScreen(api: api, isAdmin: _isAdmin),
      2 => StatsScreen(api: api),
      3 => HistoryScreen(api: api, isAdmin: _isAdmin),
      _ => ConsoleScreen(api: api, isAdmin: _isAdmin),
    };
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Today'),
          BottomNavigationBarItem(icon: Icon(Icons.diamond_outlined), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.insert_chart_outlined), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Console'),
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext ctx) async {
    final cfg = _cfg!;
    final res = await showDialog<({String base, String key})>(
      context: ctx,
      builder: (_) => SettingsDialog(baseUrl: cfg.baseUrl, apiKey: cfg.apiKey),
    );
    if (res != null) await _saveSettings(res.base, res.key);
  }
}
