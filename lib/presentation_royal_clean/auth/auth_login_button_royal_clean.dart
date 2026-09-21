import 'package:flutter/material.dart';

class AuthLoginButtonRoyalClean extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthLoginButtonRoyalClean({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.black,
              ),
            )
          : const Text('Entrar'),
    );
  }
}
