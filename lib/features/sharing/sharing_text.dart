import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

import 'models/trip_member.dart';

/// How long a sharing change may wait for the server. Offline, Firestore
/// keeps a write queued instead of failing it, so without a limit the
/// screen would wait until the phone is back online.
const sharingTimeout = Duration(seconds: 20);

/// "Owner", "Can edit" or "Can view".
String roleLabel(TripMemberRole role) => switch (role) {
      TripMemberRole.owner => 'Owner',
      TripMemberRole.editor => 'Can edit',
      TripMemberRole.viewer => 'Can view',
    };

/// A failed sharing change, in words. [doing] is what failed, such as
/// "create the invite".
String sharingErrorText(Object error, String doing) {
  if (error is FirebaseException && error.code == 'unavailable') {
    return "Couldn't $doing. You seem to be offline, and it needs a connection.";
  }
  if (error is TimeoutException) {
    return "Couldn't $doing. The server didn't answer, so check your connection and try again.";
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return "Couldn't $doing. Your account isn't allowed to do that in this trip.";
  }
  return "Couldn't $doing: $error";
}
