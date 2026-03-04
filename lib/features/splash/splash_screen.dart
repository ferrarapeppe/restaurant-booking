import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () => _progressController.forward());
    Future.delayed(const Duration(milliseconds: 3200), () { if (mounted) context.go('/'); });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(scale: _logoScale.value, child: child),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: Color(0xFFC9B06E).withOpacity(0.35), blurRadius: 40, spreadRadius: 15)],
                      ),
                      child: Image.asset('assets/images/logo_splash.png', width: 320, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                    ),
                    const SizedBox(height: 12),
                    Text('Gestione prenotazioni', style: TextStyle(color: AppColors.gold.withOpacity(0.7), fontSize: 13, letterSpacing: 3)),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, child) => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress.value,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _progress.value < 0.4 ? 'Inizializzazione...' : _progress.value < 0.8 ? 'Connessione al database...' : 'Quasi pronto...',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
