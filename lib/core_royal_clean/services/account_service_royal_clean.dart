import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const legalVersionRoyalClean = '2026-09-22';

class AccountServiceRoyalClean {
  static Future<void>? _googleInitialization;
  static FirebaseAuth get auth => FirebaseAuth.instance;

  static Future<void> google() async {
    if (kIsWeb) {
      await auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    await (_googleInitialization ??= GoogleSignIn.instance.initialize());
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw StateError('Google não retornou a autenticação.');
    await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }

  static Future<void> apple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    if (kIsWeb) {
      await auth.signInWithPopup(provider);
    } else {
      await auth.signInWithProvider(provider);
    }
  }

  static Future<void> call(String name, Map<String, dynamic> data) async {
    await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call<dynamic>(data);
  }

  static String error(Object error) {
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Login cancelado. Você pode tentar novamente.';
      }
      return 'Não foi possível entrar com Google. Confira a conexão e a configuração do aplicativo.';
    }
    if (error is FirebaseFunctionsException) {
      if ([
        'invalid-argument',
        'failed-precondition',
        'resource-exhausted',
        'permission-denied',
      ].contains(error.code)) {
        return error.message ?? 'Não foi possível concluir a solicitação.';
      }
      return 'Serviço de cadastro indisponível. Tente novamente. Se persistir, contate o atendimento.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Não foi possível entrar. Confira e-mail e senha ou recupere seu acesso.';
        case 'email-already-in-use':
          return 'Não foi possível criar a conta. Tente entrar ou recuperar seu acesso.';
        case 'account-exists-with-different-credential':
          return 'Entre com o método que você já utiliza para esta conta.';
        case 'weak-password':
        case 'password-does-not-meet-requirements':
          return 'A senha não atende à política de segurança. Use uma senha longa e exclusiva.';
        case 'invalid-email':
          return 'Confira o endereço de e-mail.';
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
        case 'network-request-failed':
          return 'Confira sua conexão e tente novamente.';
        case 'operation-not-allowed':
        case 'configuration-not-found':
          return 'Este método de acesso ainda não está disponível. Use outra opção.';
        case 'web-context-cancelled':
        case 'popup-closed-by-user':
        case 'canceled':
          return 'Login cancelado.';
        case 'user-disabled':
          return 'Acesso indisponível. Entre em contato com o atendimento.';
      }
    }
    return 'Não foi possível concluir. Confira sua conexão e tente novamente.';
  }
}

String? validateNameRoyalClean(String? value) {
  final name = value?.trim() ?? '';
  if (name.length < 2 ||
      name.length > 160 ||
      RegExp(r'[\x00-\x1F\x7F<>]').hasMatch(name) ||
      !RegExp(r'[A-Za-zÀ-ž\u0100-\uFFFF]').hasMatch(name)) {
    return 'Informe seu nome (2 a 160 caracteres).';
  }
  return null;
}

String? validateEmailRoyalClean(String? value) {
  final email = value?.trim() ?? '';
  return email.length <= 254 &&
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
      ? null
      : 'Informe um e-mail válido.';
}
