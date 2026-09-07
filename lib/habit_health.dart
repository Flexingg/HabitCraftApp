import 'package:flutter/services.dart';
import 'package:health/health.dart';

enum PermissionOutcome { granted, denied, healthConnectMissing, error }

/// One day's activity trend point (used for charts).
class TrendPoint {
  final DateTime date;
  final int steps;
  final double distanceKm;
  final double energyKcal;
  const TrendPoint({required this.date, this.steps = 0, this.distanceKm = 0, this.energyKcal = 0});
}

class TodayHealth {
  final int steps;
  final double distanceKm;
  final double energyKcal;
  final double totalKcal;
  final double sleepHours;
  final int exerciseMinutes;
  final int workouts;
  final double? weightKg;
  final double? heightCm;
  final double? restingHr;
  final double? hrvMs;
  final double? bodyTempC;
  final double? spo2;
  final double? systolic;
  final double? diastolic;

  const TodayHealth({
    this.steps = 0, this.distanceKm = 0, this.energyKcal = 0, this.totalKcal = 0,
    this.sleepHours = 0, this.exerciseMinutes = 0, this.workouts = 0,
    this.weightKg, this.heightCm, this.restingHr, this.hrvMs, this.bodyTempC,
    this.spo2, this.systolic, this.diastolic,
  });

  bool get any => steps > 0 || distanceKm > 0 || energyKcal > 0 || totalKcal > 0 ||
      sleepHours > 0 || exerciseMinutes > 0 || workouts > 0;
}

class HabitHealth {
  final Health _health = Health();
  static const _channel = MethodChannel('habitcraft/native');

  /// Broad set to authorize when the user taps "connect".
  static const requestTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.NUTRITION,
  ];

  /// The minimum needed to be useful (drives the "Connect" state in the UI).
  static const coreTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<void> configure() async {
    try { await _health.configure(); } catch (_) {}
  }

  Future<bool> isAvailable() async {
    try { return await _health.isHealthConnectAvailable(); } catch (_) { return false; }
  }

  Future<void> install() async {
    try { await _health.installHealthConnect(); } catch (_) {}
  }

  Future<bool> openPermissions() async {
    try { return (await _channel.invokeMethod<bool>('openHealthConnectPermissions')) ?? false; }
    catch (_) { return false; }
  }

  /// True once ANY core activity type is granted (subset grants still count).
  Future<bool> coreGranted() async {
    for (final t in coreTypes) {
      try { if (await _health.hasPermissions([t]) == true) return true; } catch (_) {}
    }
    return false;
  }

  Future<Set<HealthDataType>> _granted(List<HealthDataType> types) async {
    final granted = <HealthDataType>{};
    for (final t in types) {
      try { if (await _health.hasPermissions([t]) == true) granted.add(t); }
      catch (_) {}
    }
    return granted;
  }

  Future<PermissionOutcome> requestPermission() async {
    if (!await isAvailable()) return PermissionOutcome.healthConnectMissing;
    try {
      final ok = await _health.requestAuthorization(requestTypes);
      return ok == true ? PermissionOutcome.granted : PermissionOutcome.denied;
    } on HealthException {
      return PermissionOutcome.error;
    } catch (_) {
      return PermissionOutcome.error;
    }
  }

  // ---------- reads (only granted types, each metric guarded) ----------

  Future<int> _steps(DateTime s, DateTime e) async {
    try { return await _health.getTotalStepsInInterval(s, e) ?? 0; }
    catch (_) { return 0; }
  }

  Future<TodayHealth> readToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    var distanceM = 0.0, activeKcal = 0.0, totalKcal = 0.0, exerciseMin = 0.0, sleepH = 0.0;
    var workouts = 0;
    double? weight, heightM, restingHr, hrv, tempC, spo2, sys, dia;

    final steps = await _steps(start, now);

    final aggTypes = <HealthDataType>[
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.WORKOUT,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ];
    final granted = await _granted(aggTypes);
    if (granted.isNotEmpty) {
      try {
        final pts = await _health.getHealthDataFromTypes(
            startTime: start, endTime: now, types: granted.toList());
        for (final p in pts) {
          if (p.type == HealthDataType.WORKOUT) { workouts++; continue; }
          final v = _num(p);
          if (v == null) continue;
          switch (p.type) {
            case HealthDataType.DISTANCE_WALKING_RUNNING: distanceM += v; break;
            case HealthDataType.ACTIVE_ENERGY_BURNED: activeKcal += v; break;
            case HealthDataType.TOTAL_CALORIES_BURNED: totalKcal += v; break;
            case HealthDataType.EXERCISE_TIME: exerciseMin += v; break;
            case HealthDataType.SLEEP_ASLEEP: sleepH += v; break;
            case HealthDataType.WEIGHT: weight = _latest(weight, v); break;
            case HealthDataType.HEIGHT: heightM = _latest(heightM, v); break;
            case HealthDataType.RESTING_HEART_RATE: restingHr = _latest(restingHr, v); break;
            case HealthDataType.HEART_RATE_VARIABILITY_RMSSD: hrv = _latest(hrv, v); break;
            case HealthDataType.BODY_TEMPERATURE: tempC = _latest(tempC, v); break;
            case HealthDataType.BLOOD_OXYGEN: spo2 = _latest(spo2, v); break;
            case HealthDataType.BLOOD_PRESSURE_SYSTOLIC: sys = _latest(sys, v); break;
            case HealthDataType.BLOOD_PRESSURE_DIASTOLIC: dia = _latest(dia, v); break;
            default: break;
          }
        }
      } catch (_) {}
    }

    return TodayHealth(
      steps: steps,
      distanceKm: distanceM / 1000.0,
      energyKcal: activeKcal,
      totalKcal: totalKcal,
      sleepHours: sleepH,
      exerciseMinutes: exerciseMin.round(),
      workouts: workouts,
      weightKg: weight,
      heightCm: heightM == null ? null : heightM * 100.0,
      restingHr: restingHr,
      hrvMs: hrv,
      bodyTempC: tempC,
      spo2: spo2,
      systolic: sys,
      diastolic: dia,
    );
  }

  /// Steps + distance + active kcal for the last [days] days (oldest first) for charts.
  Future<List<TrendPoint>> readTrend(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (days - 1));
    final core = await _granted(coreTypes);
    final wantDistance = core.contains(HealthDataType.DISTANCE_WALKING_RUNNING);
    final wantEnergy = core.contains(HealthDataType.ACTIVE_ENERGY_BURNED);

    final out = <TrendPoint>[];
    for (var i = 0; i < days; i++) {
      final s = DateTime(start.year, start.month, start.day + i);
      final e = s.add(const Duration(days: 1));
      final steps = await _steps(s, e);
      var distM = 0.0, kcal = 0.0;
      final want = <HealthDataType>[
        if (wantDistance) HealthDataType.DISTANCE_WALKING_RUNNING,
        if (wantEnergy) HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
      if (want.isNotEmpty) {
        try {
          final pts = await _health.getHealthDataFromTypes(
              startTime: s, endTime: e, types: want);
          for (final p in pts) {
            final v = _num(p);
            if (v == null) continue;
            if (p.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
              distM += v;
            } else if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
              kcal += v;
            }
          }
        } catch (_) {}
      }
      out.add(TrendPoint(date: s, steps: steps, distanceKm: distM / 1000.0, energyKcal: kcal));
    }
    return out;
  }

  static double? _num(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  static double? _latest(double? a, double b) => a == null || b > a ? b : a;
}
