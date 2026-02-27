import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/data/models/patient.dart';

void main() {
  test('patient map roundtrip keeps profile attributes', () {
    const patient = Patient(
      id: 'p1',
      name: 'Demo',
      age: 35,
      gender: 'Female',
      allergies: ['ibuprofen', 'penicillin'],
      isPregnant: true,
      hasRenalRisk: true,
      hasHepaticRisk: false,
    );

    final restored = Patient.fromMap(patient.toMap());
    expect(restored.allergies.length, 2);
    expect(restored.isPregnant, isTrue);
    expect(restored.hasRenalRisk, isTrue);
    expect(restored.hasHepaticRisk, isFalse);
  });

  test('patient from legacy map defaults optional profile flags', () {
    final restored = Patient.fromMap({
      'id': 'legacy',
      'name': 'Legacy User',
      'age': 50,
      'gender': 'Male',
    });

    expect(restored.allergies, isEmpty);
    expect(restored.isPregnant, isFalse);
    expect(restored.hasRenalRisk, isFalse);
    expect(restored.hasHepaticRisk, isFalse);
  });
}
