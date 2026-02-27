class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
  });

  final String id;
  final String name;
  final int age;
  final String gender;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
      };

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      gender: map['gender'] as String,
    );
  }
}
