import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/consultation/consultation_controller.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const RxNovaClinicalApp());
}

class RxNovaClinicalApp extends StatelessWidget {
  const RxNovaClinicalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConsultationController.bootstrap(),
      child: MaterialApp(
        title: 'RxNova Clinical AI',
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
