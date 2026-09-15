import 'package:iconsax/iconsax.dart';
import 'package:flutter/widgets.dart';

import 'entities/vital_type.dart';

class VitalFieldSpec {
  const VitalFieldSpec({
    required this.key,
    required this.labelKey,
    required this.unit,
    required this.min,
    required this.max,
  });

  final String key;
  final String labelKey;
  final String unit;
  final double min;
  final double max;
}

class VitalDescriptor {
  const VitalDescriptor({
    required this.type,
    required this.labelKey,
    required this.icon,
    required this.fields,
  });

  final VitalType type;
  final String labelKey;
  final IconData icon;
  final List<VitalFieldSpec> fields;

  List<String> get requiredKeys =>
      fields.map((VitalFieldSpec f) => f.key).toList(growable: false);
}

const Map<VitalType, VitalDescriptor> vitalDescriptors = <VitalType, VitalDescriptor>{
  VitalType.bloodPressure: VitalDescriptor(
    type: VitalType.bloodPressure,
    labelKey: 'vitals.type.bloodPressure',
    icon: Iconsax.heart,
    fields: <VitalFieldSpec>[
      VitalFieldSpec(
        key: 'systolic',
        labelKey: 'vitals.field.systolic',
        unit: 'mmHg',
        min: 40,
        max: 300,
      ),
      VitalFieldSpec(
        key: 'diastolic',
        labelKey: 'vitals.field.diastolic',
        unit: 'mmHg',
        min: 40,
        max: 300,
      ),
    ],
  ),
  VitalType.glucose: VitalDescriptor(
    type: VitalType.glucose,
    labelKey: 'vitals.type.glucose',
    icon: Iconsax.drop,
    fields: <VitalFieldSpec>[
      VitalFieldSpec(
        key: 'glucose',
        labelKey: 'vitals.field.glucose',
        unit: 'mmol/L',
        min: 0,
        max: 50,
      ),
    ],
  ),
  VitalType.heartRate: VitalDescriptor(
    type: VitalType.heartRate,
    labelKey: 'vitals.type.heartRate',
    icon: Iconsax.activity,
    fields: <VitalFieldSpec>[
      VitalFieldSpec(
        key: 'heartRate',
        labelKey: 'vitals.field.heartRate',
        unit: 'bpm',
        min: 20,
        max: 300,
      ),
    ],
  ),
  VitalType.weight: VitalDescriptor(
    type: VitalType.weight,
    labelKey: 'vitals.type.weight',
    icon: Iconsax.weight,
    fields: <VitalFieldSpec>[
      VitalFieldSpec(
        key: 'weight',
        labelKey: 'vitals.field.weight',
        unit: 'kg',
        min: 0,
        max: 500,
      ),
    ],
  ),
  VitalType.cholesterol: VitalDescriptor(
    type: VitalType.cholesterol,
    labelKey: 'vitals.type.cholesterol',
    icon: Iconsax.chart_2,
    fields: <VitalFieldSpec>[
      VitalFieldSpec(
        key: 'ldl',
        labelKey: 'vitals.field.ldl',
        unit: 'mmol/L',
        min: 0,
        max: 30,
      ),
      VitalFieldSpec(
        key: 'hdl',
        labelKey: 'vitals.field.hdl',
        unit: 'mmol/L',
        min: 0,
        max: 30,
      ),
      VitalFieldSpec(
        key: 'total',
        labelKey: 'vitals.field.total',
        unit: 'mmol/L',
        min: 0,
        max: 30,
      ),
    ],
  ),
};
