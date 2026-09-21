import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invite_status_royal_clean_model.dart';

class InviteStatusServiceRoyalClean {
  InviteStatusServiceRoyalClean._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<InviteStatusRoyalCleanModel>> watchInvites() {
    return _firestore
        .collection('access_invites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    InviteStatusRoyalCleanModel.fromMap(doc.data(), doc.id),
              )
              .toList(),
        );
  }
}
