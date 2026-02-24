import 'package:flutter/material.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class GuestsScreen extends StatelessWidget {
  const GuestsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Clienti')),
      body: const Center(child: Text('In costruzione...', style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
