import 'package:flutter/material.dart';

import '../../data/models/prescription_row.dart';

class PrescriptionTable extends StatelessWidget {
  const PrescriptionTable({super.key, required this.rows});

  final List<PrescriptionRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No prescription extracted.');
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Drug')),
        DataColumn(label: Text('Dose')),
        DataColumn(label: Text('Frequency')),
        DataColumn(label: Text('Duration')),
      ],
      rows: rows
          .map(
            (e) => DataRow(
              cells: [
                DataCell(Text(e.drug)),
                DataCell(Text(e.dose)),
                DataCell(Text(e.frequency)),
                DataCell(Text(e.duration)),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}
