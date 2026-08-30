import 'entities/vital_type.dart';

/// What one [VitalType] needs: which `values` keys the server requires
/// (exactly these, no more, no fewer), the physiological input-sanity range
/// for each key (distinct from the *clinical* flag thresholds in
/// `core/clinical/alert_evaluator.dart` — a systolic of 190 is valid but
/// flagged; a systolic of 900 is rejected outright), the canonical unit, and
/// the translation key for its label.
///
/// Adding a sixth vital type is a new entry here, not a new layer — see
/// Decision 1 in the M4 design spec.
class VitalDescriptor {
  const VitalDescriptor({
    required this.type,
    required this.requiredKeys,
    required this.ranges,
    required this.unit,
    required this.labelKey,
  });

  final VitalType type;
  final List<String> requiredKeys;
  final Map<String, ({num min, num max})> ranges;
  final String unit;
  final String labelKey;
}

/// Source: `docs/design/2026-07-10-vitals-design.md` §7 (input-sanity ranges)
/// and §4 (`values` keys and units).
const Map<VitalType, VitalDescriptor> vitalDescriptors =
    <VitalType, VitalDescriptor>{
      VitalType.bloodPressure: VitalDescriptor(
        type: VitalType.bloodPressure,
        requiredKeys: <String>['systolic', 'diastolic'],
        ranges: <String, ({num min, num max})>{
          'systolic': (min: 40, max: 300),
          'diastolic': (min: 40, max: 300),
        },
        unit: 'mmHg',
        labelKey: 'vitals.type.bloodPressure',
      ),
      VitalType.glucose: VitalDescriptor(
        type: VitalType.glucose,
        requiredKeys: <String>['glucose'],
        ranges: <String, ({num min, num max})>{'glucose': (min: 0, max: 50)},
        unit: 'mmol/L',
        labelKey: 'vitals.type.glucose',
      ),
      VitalType.heartRate: VitalDescriptor(
        type: VitalType.heartRate,
        requiredKeys: <String>['heartRate'],
        ranges: <String, ({num min, num max})>{
          'heartRate': (min: 20, max: 300),
        },
        unit: 'bpm',
        labelKey: 'vitals.type.heartRate',
      ),
      VitalType.weight: VitalDescriptor(
        type: VitalType.weight,
        requiredKeys: <String>['weight'],
        ranges: <String, ({num min, num max})>{'weight': (min: 0, max: 500)},
        unit: 'kg',
        labelKey: 'vitals.type.weight',
      ),
      VitalType.cholesterol: VitalDescriptor(
        type: VitalType.cholesterol,
        requiredKeys: <String>['ldl', 'hdl', 'total'],
        ranges: <String, ({num min, num max})>{
          'ldl': (min: 0, max: 30),
          'hdl': (min: 0, max: 30),
          'total': (min: 0, max: 30),
        },
        unit: 'mmol/L',
        labelKey: 'vitals.type.cholesterol',
      ),
    };
