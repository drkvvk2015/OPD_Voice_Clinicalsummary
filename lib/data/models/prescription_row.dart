class PrescriptionRow {
  const PrescriptionRow({
    required this.drug,
    required this.dose,
    required this.frequency,
    required this.duration,
    this.route = 'Oral',
  });

  final String drug;
  final String dose;
  final String frequency;
  final String duration;
  final String route;

  Map<String, dynamic> toMap() => {
        'drug': drug,
        'dose': dose,
        'frequency': frequency,
        'duration': duration,
        'route': route,
      };

  factory PrescriptionRow.fromMap(Map<String, dynamic> map) {
    return PrescriptionRow(
      drug: map['drug'] as String,
      dose: map['dose'] as String,
      frequency: map['frequency'] as String,
      duration: map['duration'] as String,
      route: map['route'] as String? ?? 'Oral',
    );
  }
}
