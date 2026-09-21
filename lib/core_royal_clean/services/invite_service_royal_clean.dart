import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InviteServiceRoyalClean {
  InviteServiceRoyalClean._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> availableProfiles = [
    'Cliente',
    'Colaborador',
    'Promotor',
  ];

  static const List<String> collaboratorFunctions = [
    'VP',
    'Speed',
    'Base',
    'Web',
  ];

  static InvitePreviewResult generateInvitePreview({
    required String fullName,
    required String whatsappInput,
    required String profile,
    String? collaboratorFunction,
  }) {
    final String trimmedName = fullName.trim();
    final String normalizedWhatsappInput = normalizeDigits(whatsappInput);
    final String normalizedProfile = normalizeProfile(profile);
    final String? normalizedFunction = normalizeOptionalText(
      collaboratorFunction,
    );

    if (trimmedName.isEmpty) {
      return const InvitePreviewResult(
        success: false,
        message: 'Informe o nome.',
      );
    }

    if (!availableProfiles.contains(normalizedProfile)) {
      return const InvitePreviewResult(
        success: false,
        message: 'Selecione um perfil válido.',
      );
    }

    if (normalizedWhatsappInput.length < 10 ||
        normalizedWhatsappInput.length > 11) {
      return const InvitePreviewResult(
        success: false,
        message: 'Informe o WhatsApp com DDD em um único campo.',
      );
    }

    final String ddd = normalizedWhatsappInput.substring(0, 2);
    final String phoneNumber = normalizedWhatsappInput.substring(2);

    if (ddd.length != 2) {
      return const InvitePreviewResult(
        success: false,
        message: 'DDD inválido.',
      );
    }

    if (phoneNumber.length < 8 || phoneNumber.length > 9) {
      return const InvitePreviewResult(
        success: false,
        message: 'Número inválido.',
      );
    }

    if (normalizedProfile == 'Colaborador') {
      if (normalizedFunction == null ||
          !collaboratorFunctions.contains(normalizedFunction)) {
        return const InvitePreviewResult(
          success: false,
          message: 'Selecione uma função válida para Colaborador.',
        );
      }
    }

    final String internationalWhatsapp = buildBrazilInternationalWhatsapp(
      ddd: ddd,
      phoneNumber: phoneNumber,
    );

    final String inviteCode = _generateInviteCodeForProfile(
      profile: normalizedProfile,
      totalLength: 8,
    );

    return InvitePreviewResult(
      success: true,
      message: 'Preview gerado com sucesso.',
      preview: InvitePreviewData(
        fullName: trimmedName,
        profile: normalizedProfile,
        collaboratorFunction: normalizedProfile == 'Colaborador'
            ? normalizedFunction
            : null,
        ddd: ddd,
        phoneNumber: phoneNumber,
        internationalWhatsapp: internationalWhatsapp,
        inviteCode: inviteCode,
      ),
    );
  }

  static Future<InviteCreateResult> saveInvite({
    required InvitePreviewData preview,
  }) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        return const InviteCreateResult(
          success: false,
          message: 'Admin não autenticado.',
        );
      }

      final String inviteId = _firestore.collection('access_invites').doc().id;

      final DocumentReference<Map<String, dynamic>> inviteRef = _firestore
          .collection('access_invites')
          .doc(inviteId);

      final String whatsappProfileKey = buildWhatsappProfileIndexKey(
        preview.internationalWhatsapp,
        preview.profile,
      );

      final DocumentReference<Map<String, dynamic>> whatsappProfileIndexRef =
          _firestore
              .collection('access_invite_whatsapp_profile_index')
              .doc(whatsappProfileKey);

      final DocumentReference<Map<String, dynamic>> inviteCodeIndexRef =
          _firestore
              .collection('access_invite_code_index')
              .doc(preview.inviteCode);

      await _firestore.runTransaction((transaction) async {
        final existingWhatsappProfileDoc = await transaction.get(
          whatsappProfileIndexRef,
        );

        if (existingWhatsappProfileDoc.exists) {
          throw InviteWhatsappProfileAlreadyExistsException();
        }

        final existingInviteCodeDoc = await transaction.get(inviteCodeIndexRef);

        if (existingInviteCodeDoc.exists) {
          throw InviteCodeAlreadyExistsException();
        }

        transaction.set(inviteRef, {
          'inviteId': inviteId,
          'inviteCode': preview.inviteCode,
          'fullName': preview.fullName,
          'profile': preview.profile,
          'collaboratorFunction': preview.collaboratorFunction,
          'ddd': preview.ddd,
          'phoneNumber': preview.phoneNumber,
          'whatsapp': preview.internationalWhatsapp,
          'countryCode': '55',
          'status': 'processing',
          'registrationEnabled': true,
          'isUsed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'usedAt': null,
          'usedByUid': null,
          'createdByUid': currentUser.uid,
          'createdByEmail': currentUser.email,
        });

        transaction.set(whatsappProfileIndexRef, {
          'inviteId': inviteId,
          'inviteCode': preview.inviteCode,
          'whatsapp': preview.internationalWhatsapp,
          'profile': preview.profile,
          'collaboratorFunction': preview.collaboratorFunction,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': currentUser.uid,
        });

        transaction.set(inviteCodeIndexRef, {
          'inviteId': inviteId,
          'inviteCode': preview.inviteCode,
          'profile': preview.profile,
          'collaboratorFunction': preview.collaboratorFunction,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': currentUser.uid,
        });
      });

      return InviteCreateResult(
        success: true,
        message: 'Convite salvo com sucesso.',
        inviteId: inviteId,
      );
    } on InviteWhatsappProfileAlreadyExistsException {
      return const InviteCreateResult(
        success: false,
        message: 'Este WhatsApp já possui convite cadastrado para este perfil.',
      );
    } on InviteCodeAlreadyExistsException {
      return const InviteCreateResult(
        success: false,
        message: 'O código gerado entrou em conflito. Gere novamente.',
      );
    } catch (_) {
      return const InviteCreateResult(
        success: false,
        message: 'Não foi possível salvar o convite agora.',
      );
    }
  }

  static String normalizeDigits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizeProfile(String profile) {
    return profile.trim();
  }

  static String? normalizeOptionalText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String buildBrazilInternationalWhatsapp({
    required String ddd,
    required String phoneNumber,
  }) {
    return '55$ddd$phoneNumber';
  }

  static String buildWhatsappProfileIndexKey(
    String internationalWhatsapp,
    String profile,
  ) {
    final normalizedProfile = profile.trim().toLowerCase();
    return '${internationalWhatsapp}_$normalizedProfile';
  }

  static String buildInviteMessage({
    required String fullName,
    required String inviteCode,
    required String profile,
    String? collaboratorFunction,
  }) {
    final functionLine =
        profile == 'Colaborador' &&
            collaboratorFunction != null &&
            collaboratorFunction.isNotEmpty
        ? 'Função do colaborador: $collaboratorFunction\n'
        : '';

    return '''
Olá, $fullName!

Seu convite de acesso ao app Royal Clean foi gerado com sucesso.

Perfil do convite: $profile
$functionLine
CÓDIGO DO CONVITE
$inviteCode

Guarde esse código com segurança. Ele será usado no cadastro do aplicativo.

Equipe Royal Clean
''';
  }

  static String _generateInviteCodeForProfile({
    required String profile,
    int totalLength = 8,
  }) {
    final prefix = switch (profile) {
      'Cliente' => 'U',
      'Colaborador' => 'C',
      'Promotor' => 'P',
      _ => 'X',
    };

    final int randomLength = totalLength - prefix.length;
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    final randomPart = List.generate(
      randomLength,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return '$prefix$randomPart';
  }
}

class InvitePreviewData {
  final String fullName;
  final String profile;
  final String? collaboratorFunction;
  final String ddd;
  final String phoneNumber;
  final String internationalWhatsapp;
  final String inviteCode;

  const InvitePreviewData({
    required this.fullName,
    required this.profile,
    required this.collaboratorFunction,
    required this.ddd,
    required this.phoneNumber,
    required this.internationalWhatsapp,
    required this.inviteCode,
  });
}

class InvitePreviewResult {
  final bool success;
  final String message;
  final InvitePreviewData? preview;

  const InvitePreviewResult({
    required this.success,
    required this.message,
    this.preview,
  });
}

class InviteCreateResult {
  final bool success;
  final String message;
  final String? inviteId;

  const InviteCreateResult({
    required this.success,
    required this.message,
    this.inviteId,
  });
}

class InviteWhatsappProfileAlreadyExistsException implements Exception {}

class InviteCodeAlreadyExistsException implements Exception {}
