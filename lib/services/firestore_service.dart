import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;

  Future<void> setDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) {
    return firestore
        .collection(collection)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String collection,
    required String docId,
  }) {
    return firestore.collection(collection).doc(docId).get();
  }

  Future<void> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    return firestore.collection(collection).doc(docId).update(data);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> documentStream({
    required String collection,
    required String docId,
  }) {
    return firestore
        .collection(collection)
        .doc(docId)
        .snapshots(includeMetadataChanges: true);
  }
}
