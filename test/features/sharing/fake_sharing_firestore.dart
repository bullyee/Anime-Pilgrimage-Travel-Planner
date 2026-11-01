// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fake Firestore for GroupSharing testing without real emulator.
class FakeSharingFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> invites = {};
  final Map<String, Map<String, dynamic>> inviteCodes = {};
  final Map<String, Map<String, Map<String, dynamic>>> members = {};
  final Map<String, Map<String, dynamic>> tripsV2 = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(this, collectionPath);
  }

  @override
  WriteBatch batch() => _FakeSharingWriteBatch();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionReference implements CollectionReference<Map<String, dynamic>> {
  final FakeSharingFirestore _db;
  final String _path;

  _FakeCollectionReference(this._db, this._path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final fullPath = path != null ? '$_path/$path' : '$_path/auto_id';
    return _FakeDocumentReference(_db, fullPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final FakeSharingFirestore _db;
  final String _fullPath;

  _FakeDocumentReference(this._db, this._fullPath);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(_db, '$_fullPath/$collectionPath');
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final parts = _fullPath.split('/');
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites') _db.invites[docId] = Map.from(data);
      if (col == 'invite_codes') _db.inviteCodes[docId] = Map.from(data);
      if (col == 'tripsV2') _db.tripsV2[docId] = Map.from(data);
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      _db.members.putIfAbsent(tripId, () => {})[memberId] = Map.from(data);
    }
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final parts = _fullPath.split('/');
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites' && _db.invites.containsKey(docId)) {
        data.forEach((k, v) => _db.invites[docId]![k.toString()] = v);
      }
      if (col == 'tripsV2' && _db.tripsV2.containsKey(docId)) {
        data.forEach((k, v) => _db.tripsV2[docId]![k.toString()] = v);
      }
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      if (_db.members[tripId]?.containsKey(memberId) == true) {
        data.forEach((k, v) => _db.members[tripId]![memberId]![k.toString()] = v);
      }
    }
  }

  @override
  Future<void> delete() async {
    final parts = _fullPath.split('/');
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites') _db.invites.remove(docId);
      if (col == 'invite_codes') _db.inviteCodes.remove(docId);
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      _db.members[tripId]?.remove(memberId);
    }
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final parts = _fullPath.split('/');
    Map<String, dynamic>? data;
    bool exists = false;
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites') {
        data = _db.invites[docId];
        exists = data != null;
      } else if (col == 'invite_codes') {
        data = _db.inviteCodes[docId];
        exists = data != null;
      } else if (col == 'tripsV2') {
        data = _db.tripsV2[docId];
        exists = data != null;
      }
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      data = _db.members[tripId]?[memberId];
      exists = data != null;
    }
    return _FakeDocumentSnapshot(data, exists);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final bool _exists;

  _FakeDocumentSnapshot(this._data, this._exists);

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSharingWriteBatch implements WriteBatch {
  final List<Future<void> Function()> _ops = [];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _ops.add(() => document.set(data, options));
  }

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    _ops.add(() => document.update(data));
  }

  @override
  void delete(DocumentReference<Object?> document) {
    _ops.add(() => document.delete());
  }

  @override
  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
