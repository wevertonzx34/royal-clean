import 'package:flutter/material.dart';

class HomeBackgroundRoyalClean extends StatelessWidget {
  final Widget child;

  const HomeBackgroundRoyalClean({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
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
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x40000000),
                  Color(0x22000000),
                  Color(0x55000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
