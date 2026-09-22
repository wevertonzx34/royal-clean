import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AdminAccessRoyalClean { checking, allowed, signedOut, denied, unavailable }

bool isActiveAdminRoyalClean(Map<String, dynamic>? data, String? email) {
  final registeredEmail = data?['email'];
  return data?['eAdministrador'] == true &&
      data?['ativo'] == true &&
      registeredEmail is String &&
      email != null &&
      email.isNotEmpty &&
      registeredEmail.toLowerCase() == email.toLowerCase();
}

// Switch the permission listener whenever the authenticated identity changes.
// Generation checks discard events from a previous user's subscription.
Stream<AdminAccessRoyalClean> watchAdminAccessRoyalClean() {
  late StreamController<AdminAccessRoyalClean> controller;
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? adminSubscription;
  var generation = 0;
  void emit(AdminAccessRoyalClean state) {
    if (!controller.isClosed) controller.add(state);
  }

  controller = StreamController<AdminAccessRoyalClean>(
    onListen: () {
      authSubscription = FirebaseAuth.instance.idTokenChanges().listen(
        (user) {
          final currentGeneration = ++generation;
          unawaited(adminSubscription?.cancel());
          adminSubscription = null;
          if (user == null) {
            emit(AdminAccessRoyalClean.signedOut);
            return;
          }
          emit(AdminAccessRoyalClean.checking);
          adminSubscription = FirebaseFirestore.instance
              .collection('admin')
              .doc(user.uid)
              .snapshots(includeMetadataChanges: true)
              .listen(
                (snapshot) {
                  if (generation != currentGeneration) return;
                  // Never grant administrative access using only an old local cache.
                  if (snapshot.metadata.isFromCache ||
                      snapshot.metadata.hasPendingWrites) {
                    emit(AdminAccessRoyalClean.unavailable);
                  } else {
                    emit(
                      isActiveAdminRoyalClean(snapshot.data(), user.email)
                          ? AdminAccessRoyalClean.allowed
                          : AdminAccessRoyalClean.denied,
                    );
                  }
                },
                onError: (Object error) {
                  if (generation == currentGeneration) {
                    emit(AdminAccessRoyalClean.unavailable);
                  }
                },
              );
        },
        onError: (Object error) {
          generation++;
          unawaited(adminSubscription?.cancel());
          adminSubscription = null;
          emit(AdminAccessRoyalClean.unavailable);
        },
      );
    },
    onCancel: () async {
      generation++;
      await authSubscription?.cancel();
      await adminSubscription?.cancel();
    },
  );
  return controller.stream;
}
