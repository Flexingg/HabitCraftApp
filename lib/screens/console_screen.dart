import 'package:flutter/material.dart';

import '../bridge_api.dart';

class ConsoleScreen extends StatefulWidget {
  final BridgeApi api;
  final bool isAdmin;
  const ConsoleScreen({super.key, required this.api, required this.isAdmin});
  @override State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final _cmd = TextEditingController();
  String _log = '';
  bool _busy = true;
  String? _err;

  @override void initState() { super.initState(); if (widget.isAdmin) _refresh(); }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final l = await widget.api.consoleLog(lines: 100);
      if (mounted) setState(() { _log = l; _busy = false; _err = null; });
    } on BridgeException catch (e) {
      if (mounted) setState(() { _busy = false; _err = e.message; });
    }
  }

  Future<void> _send() async {
    final c = _cmd.text.trim();
    if (c.isEmpty) return;
    _cmd.clear();
    try {
      await widget.api.consoleSend(c);
    } on BridgeException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    await Future.delayed(const Duration(milliseconds: 600));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text('Server console', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: widget.isAdmin ? _refresh : null),
        ])),
      if (!widget.isAdmin)
        const Padding(padding: EdgeInsets.all(16),
          child: Card(child: ListTile(
            leading: Icon(Icons.lock, color: Colors.redAccent),
            title: Text('Operator only'),
            subtitle: Text('Link an op Minecraft account to use the console.'),
          )))
      else if (_err != null)
        Padding(padding: const EdgeInsets.all(16), child: Text('⚠ $_err',
            style: const TextStyle(color: Colors.orangeAccent)))
      else ...[
        Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF101315),
              borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF3A3F45))),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(_log,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF9CA3AF)))),
        )),
        Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _cmd,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Type a server command, e.g. list'),
            )),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _send, icon: const Icon(Icons.send, color: Colors.black)),
          ])),
      ],
    ]);
  }
}
