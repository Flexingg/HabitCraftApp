import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Client for the HabitCraft Bridge. Throws BridgeException with a readable message on errors.
class BridgeApi {
  String baseUrl;
  String apiKey;
  final http.Client _client;

  BridgeApi({required this.baseUrl, required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
      };

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _get(String path) async => _send('GET', path);
  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);
  Future<dynamic> _put(String path, [Map<String, dynamic>? body]) => _send('PUT', path, body);
  Future<dynamic> _delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    http.Response r;
    try {
      final uri = _u(path);
      final enc = body == null ? null : jsonEncode(body);
      r = switch (method) {
        'GET' => await _client.get(uri, headers: _headers),
        'POST' => await _client.post(uri, headers: _headers, body: enc),
        'PUT' => await _client.put(uri, headers: _headers, body: enc),
        'DELETE' => await _client.delete(uri, headers: _headers),
        _ => throw ArgumentError(method),
      };
    } on SocketException {
      throw BridgeException('Cannot reach the bridge at $baseUrl');
    } on http.ClientException {
      throw BridgeException('Cannot reach the bridge at $baseUrl');
    }
    final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      final msg = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'HTTP ${r.statusCode}';
      throw BridgeException(msg);
    }
    return decoded;
  }

  // --- status / player ---
  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(await _get('/status'));
  Future<List<dynamic>> metrics() async => (await _get('/metrics')) as List;
  Future<Map<String, dynamic>> linkPlayer(String mcName) async =>
      Map<String, dynamic>.from(await _post('/players/link', {'mc_name': mcName}));
  Future<Map<String, dynamic>?> currentPlayer() async {
    final d = await _get('/players/current');
    return d == null ? null : Map<String, dynamic>.from(d);
  }

  // --- rewards (admin) ---
  Future<List<dynamic>> rewards() async => (await _get('/rewards')) as List;
  Future<Map<String, dynamic>> createReward(Map<String, dynamic> p) async =>
      Map<String, dynamic>.from(await _post('/rewards', p));
  Future<Map<String, dynamic>> updateReward(String id, Map<String, dynamic> p) async =>
      Map<String, dynamic>.from(await _put('/rewards/$id', p));
  Future<void> deleteReward(String id) async => _delete('/rewards/$id');

  // --- incentives (admin) ---
  Future<List<dynamic>> incentives() async => (await _get('/incentives')) as List;
  Future<Map<String, dynamic>> createIncentive(Map<String, dynamic> p) async =>
      Map<String, dynamic>.from(await _post('/incentives', p));
  Future<Map<String, dynamic>> updateIncentive(String id, Map<String, dynamic> p) async =>
      Map<String, dynamic>.from(await _put('/incentives/$id', p));
  Future<void> deleteIncentive(String id) async => _delete('/incentives/$id');

  // --- events ---
  Future<Map<String, dynamic>> autoFile(String incentiveId) async =>
      Map<String, dynamic>.from(await _post('/events/auto', {'incentive_id': incentiveId}));
  Future<Map<String, dynamic>> grant(String activityId) async =>
      Map<String, dynamic>.from(await _post('/events/grant', {'activity_id': activityId}));
  Future<Map<String, dynamic>> eventsToday() async =>
      Map<String, dynamic>.from(await _get('/events/today'));

  // --- history ---
  Future<List<dynamic>> history({int limit = 100}) async =>
      (await _get('/history?limit=$limit')) as List;

  // --- console (admin) ---
  Future<String> consoleLog({int lines = 80}) async {
    final d = await _get('/console?lines=$lines');
    return (d as Map)['log'].toString();
  }

  Future<Map<String, dynamic>> consoleSend(String command) async =>
      Map<String, dynamic>.from(await _post('/console', {'command': command}));
}

class BridgeException implements Exception {
  final String message;
  BridgeException(this.message);
  @override
  String toString() => message;
}
