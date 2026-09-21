import 'package:flutter/material.dart';
import 'auth_login_button_royal_clean.dart';

class AuthFormRoyalClean extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final bool rememberAccess;
  final VoidCallback onTogglePasswordVisibility;
  final ValueChanged<bool?> onRememberAccessChanged;
  final VoidCallback onSubmit;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;

  const AuthFormRoyalClean({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.rememberAccess,
    required this.onTogglePasswordVisibility,
    required this.onRememberAccessChanged,
    required this.onSubmit,
    required this.validateEmail,
    required this.validatePassword,
  });

  // =========================================
  // CONTROLE MANUAL DA LOGO
  // =========================================
  //
  // logoScale:
  // 1.0 = tamanho base
  // 1.2 = aumenta 20%
  // 0.8 = reduz 20%
  //
  static const double logoScale = 1.9;

  // Move a logo livremente no eixo X
  // positivo = direita | negativo = esquerda
  static const double logoOffsetX = 0.0;

  // Move a logo livremente no eixo Y
  // positivo = baixo | negativo = cima
  static const double logoOffsetY = 1.2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final bool isSmall = screenWidth < 420;

    final double horizontalPadding = isSmall ? 12 : 20;

    // Base responsiva da logo conforme a tela
    final double baseLogoWidth = isSmall ? 308 : 364;
    final double baseLogoHeight = isSmall ? 168 : 196;

    // Controle final com escala manual
    final double logoWidth = baseLogoWidth * logoScale;
    final double logoHeight = baseLogoHeight * logoScale;

    return Material(
      color: Colors.transparent,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Transform.translate(
              offset: const Offset(logoOffsetX, logoOffsetY),
              child: Center(
                child: Image.asset(
                  'assets/logo/logo-gif.webp',
                  width: logoWidth,
                  height: logoHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      'Logo não encontrada',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'Digite seu e-mail',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: validateEmail,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Senha',
                  hintText: 'Digite sua senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: onTogglePasswordVisibility,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: validatePassword,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding - 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: rememberAccess,
                    onChanged: onRememberAccessChanged,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Manter acesso lembrado neste dispositivo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: AuthLoginButtonRoyalClean(
                isLoading: isLoading,
                onPressed: onSubmit,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: TextButton(
                onPressed: isLoading ? null : () {},
                child: const Text('Esqueci minha senha'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
