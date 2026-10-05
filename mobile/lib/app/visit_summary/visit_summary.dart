import '../../core/clinical/alert_evaluator.dart';
import '../../features/medication/domain/entities/adherence.dart';
import '../../features/symptoms/domain/entities/symptom_check_in.dart';
import '../../features/vitals/domain/entities/vital_reading.dart';
import '../../features/vitals/domain/entities/vital_type.dart';

enum VisitStatus { noData, stable, needsAttention }

/// Why the summary says "Needs attention". Each has a sentence under
/// `visitSummary.reason.<name>`.
enum AttentionReason {
  bpCritical,
  bpAboveTarget,
  heartRateOutOfRange,
  glucoseOutOfRange,
  lowAdherence,
  chestPain,
  urgentSymptoms,
}

/// What a patient brings to a clinic visit: averages of their vitals,
/// medication adherence and symptoms over the last [windowDays].
///
/// Lives in the app layer because it reads three features (vitals,
/// medication, symptoms) that may not import each other. The thresholds are
/// the app's existing ones (core/clinical) and the BP target used on the BP
/// trend screen; the 80% adherence line is the usual cut-off for "adherent".
class VisitSummary {
  const VisitSummary._({
    required this.windowDays,
    required this.bpSystolic,
    required this.bpDiastolic,
    required this.heartRate,
    required this.glucose,
    required this.weight,
    required this.weightChange,
    required this.adherence,
    required this.adherenceChange,
    required this.dailyAdherence,
    required this.checkInCount,
    required this.chestPainDays,
    required this.breathlessMildDays,
    required this.breathlessSevereDays,
    required this.swellingDays,
    required this.averageEnergy,
    required this.attention,
    required this.status,
    required this.targetSystolic,
    required this.targetDiastolic,
  });

  static const double adherenceGoal = 0.8;
  static const double defaultTargetSystolic = 120;
  static const double defaultTargetDiastolic = 80;

  factory VisitSummary.from({
    required int windowDays,
    required List<VitalReading> vitals,
    required Adherence adherence,
    required List<SymptomCheckIn> checkIns,
    Adherence? previousAdherence,
    List<bool?> dailyAdherence = const <bool?>[],
    VitalGoals? goals,
  }) {
    List<VitalReading> ofType(VitalType type) =>
        vitals.where((VitalReading r) => r.type == type).toList()..sort(
          (VitalReading a, VitalReading b) =>
              a.measuredAt.compareTo(b.measuredAt),
        );

    // A check-in records resting heart rate and blood pressure too. They are
    // used when nothing was logged under Vitals, so the average here matches
    // the BP trend graph, which shows Vitals readings.
    final List<VitalReading> loggedBp = ofType(VitalType.bloodPressure);
    final List<VitalReading> bp = loggedBp.isNotEmpty
        ? loggedBp
        : _fromCheckIns(checkIns, VitalType.bloodPressure);
    final List<VitalReading> weights = ofType(VitalType.weight);
    final double? sys = _mean(bp, 'systolic');
    final double? dia = _mean(bp, 'diastolic');
    final List<VitalReading> loggedHr = ofType(VitalType.heartRate);
    final double? hr = _mean(
      loggedHr.isNotEmpty
          ? loggedHr
          : _fromCheckIns(checkIns, VitalType.heartRate),
      'heartRate',
    );
    final double? glucose = _mean(ofType(VitalType.glucose), 'glucose');
    final double? weight = weights.isEmpty
        ? null
        : weights.last.values['weight'];
    final double? weightChange = weights.length < 2
        ? null
        : _round1(
            weights.last.values['weight']! - weights.first.values['weight']!,
          );

    final double targetSys = goals?.bpSystolic ?? defaultTargetSystolic;
    final double targetDia = goals?.bpDiastolic ?? defaultTargetDiastolic;

    int days(bool Function(SymptomCheckIn c) test) =>
        checkIns.where(test).length;

    final Set<AttentionReason> attention = <AttentionReason>{
      if (bp.any(
        (VitalReading r) =>
            bloodPressureSeverity(
              r.values['systolic']!,
              r.values['diastolic']!,
            ) ==
            Severity.emergency,
      ))
        AttentionReason.bpCritical,
      if (sys != null && (sys.round() > targetSys || dia!.round() > targetDia))
        AttentionReason.bpAboveTarget,
      if (hr != null && heartRateSeverity(hr) != Severity.none)
        AttentionReason.heartRateOutOfRange,
      if (glucose != null && glucoseSeverity(glucose) != Severity.none)
        AttentionReason.glucoseOutOfRange,
      if (adherence.hasData && adherence.percentage! < adherenceGoal)
        AttentionReason.lowAdherence,
      if (checkIns.any((SymptomCheckIn c) => c.chestPainPresent))
        AttentionReason.chestPain,
      if (checkIns.any(
        (SymptomCheckIn c) => c.overall.index >= Severity.urgent.index,
      ))
        AttentionReason.urgentSymptoms,
    };

    final bool anyData =
        vitals.isNotEmpty || adherence.hasData || checkIns.isNotEmpty;

    return VisitSummary._(
      windowDays: windowDays,
      bpSystolic: sys?.roundToDouble(),
      bpDiastolic: dia?.roundToDouble(),
      heartRate: hr?.roundToDouble(),
      glucose: glucose == null ? null : _round1(glucose),
      weight: weight,
      weightChange: weightChange,
      adherence: adherence,
      adherenceChange:
          (adherence.hasData && (previousAdherence?.hasData ?? false))
          ? _percent(adherence) - _percent(previousAdherence!)
          : null,
      dailyAdherence: dailyAdherence,
      checkInCount: checkIns.length,
      chestPainDays: days((SymptomCheckIn c) => c.chestPainPresent),
      breathlessMildDays: days(
        (SymptomCheckIn c) => c.shortnessOfBreath == 'MILD',
      ),
      breathlessSevereDays: days(
        (SymptomCheckIn c) => c.shortnessOfBreath == 'SEVERE',
      ),
      swellingDays: days((SymptomCheckIn c) => c.swelling),
      averageEnergy: checkIns.isEmpty
          ? null
          : _round1(
              checkIns
                      .map((SymptomCheckIn c) => c.energyLevel)
                      .reduce((int a, int b) => a + b) /
                  checkIns.length,
            ),
      attention: attention.toList()
        ..sort((AttentionReason a, AttentionReason b) => a.index - b.index),
      status: !anyData
          ? VisitStatus.noData
          : attention.isEmpty
          ? VisitStatus.stable
          : VisitStatus.needsAttention,
      targetSystolic: targetSys,
      targetDiastolic: targetDia,
    );
  }

  final int windowDays;
  final double? bpSystolic;
  final double? bpDiastolic;
  final double? heartRate;
  final double? glucose;
  final double? weight;
  final double? weightChange;
  final Adherence adherence;

  /// Percentage points against the period before; null without both.
  final int? adherenceChange;

  /// One entry per day, oldest first: true when every dose due was taken,
  /// false when one was missed, null when nothing was due.
  final List<bool?> dailyAdherence;
  final int checkInCount;
  final int chestPainDays;
  final int breathlessMildDays;
  final int breathlessSevereDays;
  final int swellingDays;
  final double? averageEnergy;
  final List<AttentionReason> attention;
  final VisitStatus status;
  final double targetSystolic;
  final double targetDiastolic;

  int? get adherencePercent => adherence.hasData ? _percent(adherence) : null;

  bool get bpAboveTarget => attention.contains(AttentionReason.bpAboveTarget);

  static int _percent(Adherence a) => (a.percentage! * 100).round();

  static double _round1(double v) => (v * 10).roundToDouble() / 10;

  static List<VitalReading> _fromCheckIns(
    List<SymptomCheckIn> checkIns,
    VitalType type,
  ) {
    final List<VitalReading> out = <VitalReading>[];
    for (final SymptomCheckIn c in checkIns) {
      final Map<String, double> values = <String, double>{};
      if (type == VitalType.heartRate && c.data['heartRate'] is num) {
        values['heartRate'] = (c.data['heartRate'] as num).toDouble();
      }
      final Object? bp = c.data['bloodPressure'];
      if (type == VitalType.bloodPressure &&
          bp is Map &&
          bp['systolic'] is num &&
          bp['diastolic'] is num) {
        values['systolic'] = (bp['systolic'] as num).toDouble();
        values['diastolic'] = (bp['diastolic'] as num).toDouble();
      }
      if (values.isEmpty) continue;
      out.add(
        VitalReading(
          clientRecordId: c.clientRecordId,
          serverId: null,
          type: type,
          values: values,
          flagged: null,
          bmi: null,
          measuredAt: c.measuredAt,
          note: null,
        ),
      );
    }
    return out;
  }

  static double? _mean(List<VitalReading> readings, String key) {
    final List<double> values = <double>[
      for (final VitalReading r in readings)
        if (r.values[key] != null) r.values[key]!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((double a, double b) => a + b) / values.length;
  }
}
