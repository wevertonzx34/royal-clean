import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';

class SplashPageRoyalClean extends StatefulWidget {
  final Future<void> firebaseInitialization;

  const SplashPageRoyalClean({super.key, required this.firebaseInitialization});

  @override
  State<SplashPageRoyalClean> createState() => _SplashPageRoyalCleanState();
}

class _SplashPageRoyalCleanState extends State<SplashPageRoyalClean> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      widget.firebaseInitialization,
    ]);

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, AppRoutesRoyalClean.preview);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final double logoWidth = screenWidth < 420 ? 260 : 340;
    final double logoHeight = screenWidth < 420 ? 260 : 340;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF021722),
              Color(0xFF052534),
              Color(0xFF08364A),
              Color(0xFF052534),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo/logo-splash.webp',
                    width: logoWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 140,
                        height: 140,
                        child: Center(
                          child: Text(
                            'Logo não encontrada',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Inicializando ambiente...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
