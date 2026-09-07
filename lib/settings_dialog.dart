import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  const SettingsDialog({super.key, required this.baseUrl, required this.apiKey});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _base = TextEditingController(text: widget.baseUrl);
  late final TextEditingController _key = TextEditingController(text: widget.apiKey);

  @override
  void dispose() {
    _base.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bridge Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _base,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Bridge URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            decoration: const InputDecoration(labelText: 'API Key'),
          ),
          const SizedBox(height: 12),
          const Text('Points to the HabitCraft Bridge running on your LAN box.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (base: _base.text.trim(), key: _key.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
