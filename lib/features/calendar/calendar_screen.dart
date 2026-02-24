import 'package:flutter/material.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Calendario')),
      body: const Center(child: Text('In costruzione...', style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
