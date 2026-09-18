import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';

/// Stitch: S00 - Splash Screen, 8cc00e1f5ad34f67b29b7ba2720ac1e6.
///
/// Versi [BootScreen] menavigasi sendiri setelah 1 detik dan dipertahankan
/// untuk alur tanpa controller. [SplashPlaceholder] adalah tampilan visual
/// yang sama tanpa navigasi, dipakai [ExamApp] saat memuat state tersimpan.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class SplashPlaceholder extends StatelessWidget {
  const SplashPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'ExamSeal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                  color: Color(0xFF171717),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootScreenState extends State<BootScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SplashPlaceholder();
}
