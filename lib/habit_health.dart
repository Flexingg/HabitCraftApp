import 'package:health/health.dart';

/// Wraps Health Connect reads (health ^13). Data stays on-device — we only report
/// threshold-met events to the bridge.
class HabitHealth {
  final Health _health = Health();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<bool> configure() async {
    try {
      await _health.configure();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return await _health.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _health.requestAuthorization(_types) == true;
    } catch (_) {
      return false;
    }
  }

  /// Reads today's totals (local midnight -> now). null if permission/data unavailable.
  Future<TodayHealth?> readToday() async {
    if (!await hasPermission()) return null;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    int steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(start, now) ?? 0;
    } catch (_) {}

    double distanceM = 0, energyKcal = 0;
    try {
      final agg = await _health.getHealthAggregateDataFromTypes(
        types: _types,
        startDate: start,
        endDate: now,
      );
      for (final p in agg) {
        final n = (p.value as NumericHealthValue).numericValue;
        switch (p.type) {
          case HealthDataType.DISTANCE_WALKING_RUNNING:
            distanceM += n;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            energyKcal += n;
          default:
            break;
        }
      }
    } catch (_) {}

    return TodayHealth(
      steps: steps,
      distanceKm: distanceM / 1000.0,
      energyKcal: energyKcal,
    );
  }
}

class TodayHealth {
  final int steps;
  final double distanceKm;
  final double energyKcal;
  TodayHealth({required this.steps, required this.distanceKm, required this.energyKcal});
}
