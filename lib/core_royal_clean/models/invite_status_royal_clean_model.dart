import 'package:cloud_firestore/cloud_firestore.dart';

class InviteStatusRoyalCleanModel {
  final String inviteId;
  final String inviteCode;
  final String fullName;
  final String profile;
  final String? collaboratorFunction;
  final String whatsapp;
  final String status;
  final bool registrationEnabled;
  final bool isUsed;
  final DateTime? createdAt;
  final DateTime? usedAt;
  final String? usedByUid;
  final String? createdByUid;
  final String? createdByEmail;

  const InviteStatusRoyalCleanModel({
    required this.inviteId,
    required this.inviteCode,
    required this.fullName,
    required this.profile,
    required this.collaboratorFunction,
    required this.whatsapp,
    required this.status,
    required this.registrationEnabled,
    required this.isUsed,
    required this.createdAt,
    required this.usedAt,
    required this.usedByUid,
    required this.createdByUid,
    required this.createdByEmail,
  });

  factory InviteStatusRoyalCleanModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final createdAtRaw = map['createdAt'];
    final usedAtRaw = map['usedAt'];

    DateTime? createdAt;
    DateTime? usedAt;

    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    }

    if (usedAtRaw is Timestamp) {
      usedAt = usedAtRaw.toDate();
    }

    final rawFunction = map['collaboratorFunction']?.toString().trim();

    return InviteStatusRoyalCleanModel(
      inviteId: (map['inviteId'] ?? documentId).toString(),
      inviteCode: (map['inviteCode'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      profile: (map['profile'] ?? '').toString(),
      collaboratorFunction: (rawFunction == null || rawFunction.isEmpty)
          ? null
          : rawFunction,
      whatsapp: (map['whatsapp'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      registrationEnabled: map['registrationEnabled'] == true,
      isUsed: map['isUsed'] == true,
      createdAt: createdAt,
      usedAt: usedAt,
      usedByUid: map['usedByUid']?.toString(),
      createdByUid: map['createdByUid']?.toString(),
      createdByEmail: map['createdByEmail']?.toString(),
    );
  }

  bool get isActive => registrationEnabled && !isUsed;

  bool get isProcessing => status.trim().toLowerCase() == 'processing';
}
