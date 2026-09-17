import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/symptom_check_in.dart';
import '../../symptom_providers.dart';

const Map<String, int> chestPainSeverityByLevel = <String, int>{
  'NONE': 0,
  'MILD': 2,
  'MODERATE': 5,
  'SEVERE': 8,
};

const Object _keep = Object();

class SymptomFormState {
  const SymptomFormState({
    this.chestPain = 'NONE',
    this.shortnessOfBreath = 'NONE',
    this.heartRate,
    this.bpSystolic,
    this.bpDiastolic,
    this.swelling = false,
    this.energyLevel = 5,
    this.worseThanYesterday = false,
    this.note,
    this.isSubmitting = false,
    this.generalError,
    this.fieldErrors = const <String, String>{},
    this.result,
  });

  final String chestPain;
  final String shortnessOfBreath;

  final int? heartRate;
  final int? bpSystolic;
  final int? bpDiastolic;

  final bool swelling;
  final int energyLevel;
  final bool worseThanYesterday;
  final String? note;
  final bool isSubmitting;
  final String? generalError;
  final Map<String, String> fieldErrors;
  final SymptomCheckIn? result;

  SymptomFormState copyWith({
    String? chestPain,
    String? shortnessOfBreath,
    Object? heartRate = _keep,
    Object? bpSystolic = _keep,
    Object? bpDiastolic = _keep,
    bool? swelling,
    int? energyLevel,
    bool? worseThanYesterday,
    String? note,
    bool? isSubmitting,
    String? generalError,
    bool clearGeneralError = false,
    Map<String, String>? fieldErrors,
    SymptomCheckIn? result,
  }) => SymptomFormState(
    chestPain: chestPain ?? this.chestPain,
    shortnessOfBreath: shortnessOfBreath ?? this.shortnessOfBreath,
    heartRate: heartRate == _keep ? this.heartRate : heartRate as int?,
    bpSystolic: bpSystolic == _keep ? this.bpSystolic : bpSystolic as int?,
    bpDiastolic: bpDiastolic == _keep ? this.bpDiastolic : bpDiastolic as int?,
    swelling: swelling ?? this.swelling,
    energyLevel: energyLevel ?? this.energyLevel,
    worseThanYesterday: worseThanYesterday ?? this.worseThanYesterday,
    note: note ?? this.note,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    generalError: clearGeneralError
        ? null
        : (generalError ?? this.generalError),
    fieldErrors: fieldErrors ?? this.fieldErrors,
    result: result ?? this.result,
  );
}

class SymptomFormController extends Notifier<SymptomFormState> {
  @override
  SymptomFormState build() => const SymptomFormState();

  void setChestPain(String level) => state = state.copyWith(chestPain: level);

  void setShortnessOfBreath(String value) =>
      state = state.copyWith(shortnessOfBreath: value);

  void setHeartRate(int? value) => state = state.copyWith(
    heartRate: value,
    clearGeneralError: true,
    fieldErrors: const <String, String>{},
  );

  void setBpSystolic(int? value) => state = state.copyWith(
    bpSystolic: value,
    clearGeneralError: true,
    fieldErrors: const <String, String>{},
  );

  void setBpDiastolic(int? value) => state = state.copyWith(
    bpDiastolic: value,
    clearGeneralError: true,
    fieldErrors: const <String, String>{},
  );

  void setSwelling(bool value) => state = state.copyWith(swelling: value);

  void setEnergyLevel(int value) => state = state.copyWith(energyLevel: value);

  void setWorseThanYesterday(bool value) =>
      state = state.copyWith(worseThanYesterday: value);

  void setNote(String value) => state = state.copyWith(note: value);

  Future<void> submit() async {
    final Map<String, String> errors = <String, String>{};

    final int? hr = state.heartRate;
    if (hr == null) {
      errors['heartRate'] = 'symptoms.checkIn.err.hrRequired';
    } else if (hr < 20 || hr > 250) {
      errors['heartRate'] = 'symptoms.checkIn.err.hrRange';
    }

    final int? sys = state.bpSystolic;
    if (sys == null) {
      errors['bpSystolic'] = 'symptoms.checkIn.err.sysRequired';
    } else if (sys < 40 || sys > 300) {
      errors['bpSystolic'] = 'symptoms.checkIn.err.sysRange';
    }

    final int? dia = state.bpDiastolic;
    if (dia == null) {
      errors['bpDiastolic'] = 'symptoms.checkIn.err.diaRequired';
    } else if (dia < 40 || dia > 300) {
      errors['bpDiastolic'] = 'symptoms.checkIn.err.diaRange';
    }

    if (errors.isEmpty && sys! <= dia!) {
      errors['bpDiastolic'] = 'symptoms.checkIn.systolicMustExceedDiastolic';
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors, clearGeneralError: true);
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearGeneralError: true,
      fieldErrors: const <String, String>{},
    );

    final bool chestPainPresent = state.chestPain != 'NONE';
    final Map<String, dynamic> data = <String, dynamic>{
      'chestPain': <String, dynamic>{
        'present': chestPainPresent,
        if (chestPainPresent)
          'severity': chestPainSeverityByLevel[state.chestPain],
      },
      'shortnessOfBreath': state.shortnessOfBreath,
      'heartRate': state.heartRate,
      'bloodPressure': <String, dynamic>{
        'systolic': state.bpSystolic,
        'diastolic': state.bpDiastolic,
      },
      'swelling': state.swelling,
      'energyLevel': state.energyLevel,
      if (state.worseThanYesterday)
        'worseThanYesterday': <String, dynamic>{
          if (chestPainPresent) 'chestPain': true,
          if (state.shortnessOfBreath != 'NONE') 'shortnessOfBreath': true,
        },
    };

    final SymptomCheckIn entity = await ref
        .read(symptomRepositoryProvider)
        .submit(
          data: data,
          note: (state.note?.trim().isEmpty ?? true)
              ? null
              : state.note!.trim(),
        );

    state = state.copyWith(isSubmitting: false, result: entity);
  }
}

final NotifierProvider<SymptomFormController, SymptomFormState>
symptomFormControllerProvider =
    NotifierProvider.autoDispose<SymptomFormController, SymptomFormState>(
      SymptomFormController.new,
    );
