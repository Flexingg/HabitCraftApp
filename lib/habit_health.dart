import 'package:flutter/services.dart';
import 'package:health/health.dart';

/// Result of a permission request so the UI can tell the user WHAT happened.
enum PermissionOutcome { granted, denied, healthConnectMissing, error }

/// Snapshot of today's health readings (real, from Health Connect). Units are
/// best-guess SI for each type; you can confirm exact magnitudes on-device.
class TodayHealth {
  final int steps;
  final double distanceKm;
  final double energyKcal;   // active energy burned
  final double totalKcal;    // total calories burned
  final double sleepHours;   // time asleep today
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

/// Wraps Health Connect. Data stays on-device; the app only reports "threshold met".
class HabitHealth {
  final Health _health = Health();
  static const _channel = MethodChannel('habitcraft/native');

  /// Broad set of read types to authorize. Only confirmed-supported types.
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

  Future<void> configure() async {
    try { await _health.configure(); } catch (_) {}
  }

  Future<bool> isAvailable() async {
    try { return await _health.isHealthConnectAvailable(); } catch (_) { return false; }
  }

  Future<void> install() async {
    try { await _health.installHealthConnect(); } catch (_) {}
  }

  /// Deep-link into Health Connect to let the user toggle HabitCraft's access.
  Future<bool> openPermissions() async {
    try { return (await _channel.invokeMethod<bool>('openHealthConnectPermissions')) ?? false; }
    catch (_) { return false; }
  }

  Future<bool> hasPermission() async {
    try { return (await _health.hasPermissions(requestTypes)) ?? false; }
    catch (_) { return false; }
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

  /// Read today's data (local midnight -> now). Each metric is independently guarded
  /// so one unsupported type never fails the whole read.
  Future<TodayHealth> readToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    var distanceM = 0.0, activeKcal = 0.0, totalKcal = 0.0, exerciseMin = 0.0, sleepH = 0.0;
    var workouts = 0, steps = 0;
    double? weight, heightM, restingHr, hrv, tempC, spo2, sys, dia;

    // Steps: dedicated aggregate getter.
    try { steps = await _health.getTotalStepsInInterval(start, now) ?? 0; } catch (_) {}

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

    try {
      final pts = await _health.getHealthDataFromTypes(
          startTime: start, endTime: now, types: aggTypes);
      for (final p in pts) {
        if (p.type == HealthDataType.WORKOUT) { workouts++; continue; }
        final v = _num(p);
        if (v == null) continue;
        switch (p.type) {
          case HealthDataType.DISTANCE_WALKING_RUNNING: distanceM += v; break;
          case HealthDataType.ACTIVE_ENERGY_BURNED: activeKcal += v; break;
          case HealthDataType.TOTAL_CALORIES_BURNED: totalKcal += v; break;
          case HealthDataType.EXERCISE_TIME: exerciseMin += v; break;
          case HealthDataType.WORKOUT: workouts++; break;
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

  static double? _num(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  static double? _latest(double? a, double b) => a == null || b > a ? b : a;
}
