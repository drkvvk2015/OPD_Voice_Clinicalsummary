import 'dart:convert';

class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.allergies = const <String>[],
    this.isPregnant = false,
    this.hasRenalRisk = false,
    this.hasHepaticRisk = false,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
  final List<String> allergies;
  final bool isPregnant;
  final bool hasRenalRisk;
  final bool hasHepaticRisk;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'allergies_json': jsonEncode(allergies),
        'is_pregnant': isPregnant ? 1 : 0,
        'renal_risk': hasRenalRisk ? 1 : 0,
        'hepatic_risk': hasHepaticRisk ? 1 : 0,
      };

  factory Patient.fromMap(Map<String, dynamic> map) {
    final allergiesJson = map['allergies_json'];
    List<String> decodedAllergies = const <String>[];
    if (allergiesJson is String && allergiesJson.trim().isNotEmpty) {
      final parsed = jsonDecode(allergiesJson);
      if (parsed is List) {
        decodedAllergies =
            parsed.map((e) => e.toString()).toList(growable: false);
      }
    }

    return Patient(
      id: map['id'] as String,
      name: map['name'] as String,
      age: (map['age'] as num).toInt(),
      gender: map['gender'] as String,
      allergies: decodedAllergies,
      isPregnant: _boolFromDb(map['is_pregnant']),
      hasRenalRisk: _boolFromDb(map['renal_risk']),
      hasHepaticRisk: _boolFromDb(map['hepatic_risk']),
    );
  }

  static bool _boolFromDb(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value == 1;
    }

    final normalized = value.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
}
