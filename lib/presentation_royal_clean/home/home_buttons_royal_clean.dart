import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'package:flutter/material.dart';

class HomePrimaryButtonRoyalClean extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  const HomePrimaryButtonRoyalClean({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutButtonRoyalClean(
      id: 'home_buttons_royal_clean.control_01',
      instanceKey: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: tactileTapRoyalClean(onPressed),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xB8062B3D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF155A78)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0x120096C7),
                  border: Border.all(color: const Color(0x220096C7)),
                ),
                child: Icon(icon, color: const Color(0xFF0096C7), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
